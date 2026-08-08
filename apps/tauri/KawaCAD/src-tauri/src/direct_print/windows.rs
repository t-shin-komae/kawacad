use super::{
    DirectPrintArtifact, DirectPrintAvailability, DirectPrintAvailabilityStatus,
    DirectPrintOptions, DirectPrinter, InspectPrinterRequest, PreparedDirectPrint,
    PrinterInspection,
};
use kawacad_core::output::PrintableAreaMm;
use kawacad_output_engine::{PrintRenderCommand, PrintRenderData, StrokeKind};
use std::ffi::OsStr;
use std::iter;
use std::mem;
use std::os::windows::ffi::OsStrExt;
use std::ptr;
use winapi::shared::minwindef::LPBYTE;
use winapi::um::wingdi::{
    Arc, CreateDCW, CreatePen, DeleteDC, DeleteObject, Ellipse, EndDoc, EndPage, GetDeviceCaps,
    LineTo, MoveToEx, SelectObject, SetArcDirection, SetBkMode, SetTextColor, StartDocW, StartPage,
    TextOutW, AD_CLOCKWISE, DMDUP_SIMPLEX, DMORIENT_LANDSCAPE, DMORIENT_PORTRAIT, DMPAPER_A4,
    DM_DUPLEX, DM_IN_BUFFER, DM_NUP, DM_ORIENTATION, DM_OUT_BUFFER, DM_PAPERSIZE, DM_SCALE,
    DOCINFOW, HORZRES, LOGPIXELSX, LOGPIXELSY, PHYSICALHEIGHT, PHYSICALOFFSETX, PHYSICALOFFSETY,
    PHYSICALWIDTH, PS_DASH, PS_SOLID, RGB, TRANSPARENT, VERTRES,
};
use winapi::um::winspool::{
    ClosePrinter, DocumentPropertiesW, EnumPrintersW, OpenPrinterW, PRINTER_ENUM_CONNECTIONS,
    PRINTER_ENUM_LOCAL, PRINTER_INFO_2W,
};

const IDOK: i32 = 1;

pub(super) fn availability() -> DirectPrintAvailability {
    DirectPrintAvailability {
        status: DirectPrintAvailabilityStatus::Available,
        reason: None,
    }
}

pub(super) fn list_printers() -> Result<Vec<DirectPrinter>, String> {
    let mut bytes_needed = 0;
    let mut count = 0;
    // The first call is the documented buffer-size query. EnumPrintersW returns false here.
    unsafe {
        EnumPrintersW(
            PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
            ptr::null_mut(),
            2,
            ptr::null_mut(),
            0,
            &mut bytes_needed,
            &mut count,
        );
    }
    if bytes_needed == 0 {
        return Ok(Vec::new());
    }

    let mut buffer = vec![0u8; bytes_needed as usize];
    let succeeded = unsafe {
        EnumPrintersW(
            PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
            ptr::null_mut(),
            2,
            buffer.as_mut_ptr() as LPBYTE,
            bytes_needed,
            &mut bytes_needed,
            &mut count,
        )
    };
    if succeeded == 0 {
        return Err(last_error("Could not enumerate Windows printers"));
    }

    let printers = buffer.as_ptr() as *const PRINTER_INFO_2W;
    let mut result = Vec::with_capacity(count as usize);
    for index in 0..count as usize {
        let info = unsafe { &*printers.add(index) };
        if info.pPrinterName.is_null() {
            continue;
        }
        let name = wide_ptr_to_string(info.pPrinterName);
        result.push(DirectPrinter {
            id: name.clone(),
            display_name: name,
            selectable: true,
        });
    }
    Ok(result)
}

pub(super) fn inspect_printer(
    request: &InspectPrinterRequest,
) -> Result<PrinterInspection, String> {
    let configuration = configured_printer(&request.printer_id, &request.options)?;
    Ok(PrinterInspection {
        printer_id: request.printer_id.clone(),
        selectable: true,
        printable_area_mm: Some(configuration.printable_area_mm),
        reason: None,
        capability_fingerprint: Some(configuration.fingerprint),
    })
}

pub(super) fn send(prepared: &PreparedDirectPrint) -> Result<(), String> {
    let inspection = inspect_printer(&InspectPrinterRequest {
        printer_id: prepared.printer_id.clone(),
        options: prepared.options.clone(),
    })?;
    if inspection.capability_fingerprint.as_deref() != Some(&prepared.capability_fingerprint) {
        return Err(
            "Prepared direct print is stale because printer capabilities changed".to_owned(),
        );
    }
    let DirectPrintArtifact::Windows(render_data) = &prepared.artifact else {
        return Err("Prepared direct print has an invalid Windows artifact".to_owned());
    };
    let configuration = configured_printer(&prepared.printer_id, &prepared.options)?;
    render_to_printer(&prepared.printer_id, &configuration, render_data)
}

struct PrinterConfiguration {
    devmode: Vec<usize>,
    printable_area_mm: PrintableAreaMm,
    dpi_x: i32,
    dpi_y: i32,
    physical_width: i32,
    physical_height: i32,
    physical_offset_x: i32,
    physical_offset_y: i32,
    fingerprint: String,
}

fn configured_printer(
    printer_name: &str,
    options: &DirectPrintOptions,
) -> Result<PrinterConfiguration, String> {
    let wide_name = wide(printer_name);
    let mut printer = ptr::null_mut();
    if unsafe { OpenPrinterW(wide_name.as_ptr() as *mut _, &mut printer, ptr::null_mut()) } == 0 {
        return Err(last_error("Could not open the selected Windows printer"));
    }
    let result = (|| {
        let byte_count = unsafe {
            DocumentPropertiesW(
                ptr::null_mut(),
                printer,
                wide_name.as_ptr(),
                ptr::null_mut(),
                ptr::null_mut(),
                0,
            )
        };
        if byte_count <= 0 {
            return Err(last_error("Could not read the printer DEVMODE"));
        }
        let word_count = (byte_count as usize).div_ceil(mem::size_of::<usize>());
        let mut devmode = vec![0usize; word_count];
        let devmode_ptr = devmode.as_mut_ptr().cast();
        if unsafe {
            DocumentPropertiesW(
                ptr::null_mut(),
                printer,
                wide_name.as_ptr(),
                devmode_ptr,
                ptr::null_mut(),
                DM_OUT_BUFFER,
            )
        } != IDOK
        {
            return Err(last_error("Could not obtain the printer DEVMODE"));
        }
        normalize_devmode(devmode_ptr, options)?;
        if unsafe {
            DocumentPropertiesW(
                ptr::null_mut(),
                printer,
                wide_name.as_ptr(),
                devmode_ptr,
                devmode_ptr,
                DM_IN_BUFFER | DM_OUT_BUFFER,
            )
        } != IDOK
        {
            return Err(last_error(
                "The selected printer rejected A4 100% simplex settings",
            ));
        }
        let dc = unsafe {
            CreateDCW(
                wide("WINSPOOL").as_ptr(),
                wide_name.as_ptr(),
                ptr::null(),
                devmode_ptr,
            )
        };
        if dc.is_null() {
            return Err(last_error(
                "Could not create the Windows printer device context",
            ));
        }
        let result = device_context_configuration(dc, devmode);
        unsafe { DeleteDC(dc) };
        result
    })();
    unsafe { ClosePrinter(printer) };
    result
}

fn normalize_devmode(
    devmode: *mut winapi::um::wingdi::DEVMODEW,
    options: &DirectPrintOptions,
) -> Result<(), String> {
    let orientation = match options.orientation.as_str() {
        "portrait" => DMORIENT_PORTRAIT,
        "landscape" => DMORIENT_LANDSCAPE,
        _ => return Err("Direct printing requires a valid A4 orientation".to_owned()),
    } as i16;
    unsafe {
        (*devmode).dmFields |= DM_ORIENTATION | DM_PAPERSIZE | DM_SCALE | DM_DUPLEX | DM_NUP;
        let settings = (*devmode).u1.s1_mut();
        settings.dmOrientation = orientation;
        settings.dmPaperSize = DMPAPER_A4 as i16;
        settings.dmScale = 100;
        (*devmode).dmDuplex = DMDUP_SIMPLEX as i16;
        *(*devmode).u2.dmNup_mut() = 1;
    }
    Ok(())
}

fn device_context_configuration(
    dc: winapi::shared::windef::HDC,
    devmode: Vec<usize>,
) -> Result<PrinterConfiguration, String> {
    let dpi_x = unsafe { GetDeviceCaps(dc, LOGPIXELSX) };
    let dpi_y = unsafe { GetDeviceCaps(dc, LOGPIXELSY) };
    let physical_width = unsafe { GetDeviceCaps(dc, PHYSICALWIDTH) };
    let physical_height = unsafe { GetDeviceCaps(dc, PHYSICALHEIGHT) };
    let physical_offset_x = unsafe { GetDeviceCaps(dc, PHYSICALOFFSETX) };
    let physical_offset_y = unsafe { GetDeviceCaps(dc, PHYSICALOFFSETY) };
    let horizontal_resolution = unsafe { GetDeviceCaps(dc, HORZRES) };
    let vertical_resolution = unsafe { GetDeviceCaps(dc, VERTRES) };
    if dpi_x <= 0
        || dpi_y <= 0
        || physical_width <= 0
        || physical_height <= 0
        || horizontal_resolution <= 0
        || vertical_resolution <= 0
    {
        return Err("The selected printer did not report a usable physical page area".to_owned());
    }
    let to_mm_x = |pixels: i32| f64::from(pixels) * 25.4 / f64::from(dpi_x);
    let to_mm_y = |pixels: i32| f64::from(pixels) * 25.4 / f64::from(dpi_y);
    let printable_area_mm = PrintableAreaMm {
        left_mm: to_mm_x(physical_offset_x - physical_width / 2),
        right_mm: to_mm_x(physical_offset_x + horizontal_resolution - physical_width / 2),
        top_mm: to_mm_y(physical_height / 2 - physical_offset_y),
        bottom_mm: to_mm_y(physical_height / 2 - physical_offset_y - vertical_resolution),
    };
    Ok(PrinterConfiguration {
        devmode,
        printable_area_mm,
        dpi_x,
        dpi_y,
        physical_width,
        physical_height,
        physical_offset_x,
        physical_offset_y,
        fingerprint: format!(
            "windows:{dpi_x}:{dpi_y}:{physical_width}:{physical_height}:{physical_offset_x}:{physical_offset_y}:{horizontal_resolution}:{vertical_resolution}"
        ),
    })
}

fn render_to_printer(
    printer_name: &str,
    configuration: &PrinterConfiguration,
    render_data: &PrintRenderData,
) -> Result<(), String> {
    let name = wide(printer_name);
    let dc = unsafe {
        CreateDCW(
            wide("WINSPOOL").as_ptr(),
            name.as_ptr(),
            ptr::null(),
            configuration.devmode.as_ptr().cast(),
        )
    };
    if dc.is_null() {
        return Err(last_error(
            "Could not create the Windows printer device context",
        ));
    }
    let result = (|| {
        let document_name = wide("KawaCAD");
        let info = DOCINFOW {
            cbSize: mem::size_of::<DOCINFOW>() as i32,
            lpszDocName: document_name.as_ptr(),
            lpszOutput: ptr::null(),
            lpszDatatype: ptr::null(),
            fwType: 0,
        };
        if unsafe { StartDocW(dc, &info) } <= 0 {
            return Err(last_error("Could not start the Windows print job"));
        }
        for page in &render_data.pages {
            if unsafe { StartPage(dc) } <= 0 {
                return Err(last_error("Could not start a Windows print page"));
            }
            draw_page(dc, configuration, page)?;
            if unsafe { EndPage(dc) } <= 0 {
                return Err(last_error("Could not finish a Windows print page"));
            }
        }
        if unsafe { EndDoc(dc) } <= 0 {
            return Err(last_error("Could not submit the Windows print job"));
        }
        Ok(())
    })();
    unsafe { DeleteDC(dc) };
    result
}

fn draw_page(
    dc: winapi::shared::windef::HDC,
    configuration: &PrinterConfiguration,
    page: &kawacad_output_engine::PrintRenderPage,
) -> Result<(), String> {
    unsafe { SetArcDirection(dc, AD_CLOCKWISE as i32) };
    for command in &page.commands {
        match command {
            PrintRenderCommand::StrokeLine {
                start_mm,
                end_mm,
                style,
                kind,
            } => with_pen(dc, style, *kind, configuration, || unsafe {
                MoveToEx(
                    dc,
                    x(configuration, start_mm.x_mm),
                    y(configuration, start_mm.y_mm),
                    ptr::null_mut(),
                );
                LineTo(
                    dc,
                    x(configuration, end_mm.x_mm),
                    y(configuration, end_mm.y_mm),
                );
            }),
            PrintRenderCommand::StrokeCircle {
                center_mm,
                radius_mm,
                style,
            } => with_pen(dc, style, StrokeKind::Graphic, configuration, || unsafe {
                Ellipse(
                    dc,
                    x(configuration, center_mm.x_mm - radius_mm),
                    y(configuration, center_mm.y_mm + radius_mm),
                    x(configuration, center_mm.x_mm + radius_mm),
                    y(configuration, center_mm.y_mm - radius_mm),
                );
            }),
            PrintRenderCommand::StrokeArc {
                center_mm,
                radius_mm,
                start_angle_rad,
                sweep_angle_rad,
                style,
            } => with_pen(dc, style, StrokeKind::Graphic, configuration, || unsafe {
                let start_x = center_mm.x_mm + radius_mm * start_angle_rad.cos();
                let start_y = center_mm.y_mm + radius_mm * start_angle_rad.sin();
                let end_angle = start_angle_rad + sweep_angle_rad;
                let end_x = center_mm.x_mm + radius_mm * end_angle.cos();
                let end_y = center_mm.y_mm + radius_mm * end_angle.sin();
                Arc(
                    dc,
                    x(configuration, center_mm.x_mm - radius_mm),
                    y(configuration, center_mm.y_mm + radius_mm),
                    x(configuration, center_mm.x_mm + radius_mm),
                    y(configuration, center_mm.y_mm - radius_mm),
                    x(configuration, start_x),
                    y(configuration, start_y),
                    x(configuration, end_x),
                    y(configuration, end_y),
                );
            }),
            PrintRenderCommand::DrawPoint { center_mm, style } => {
                with_pen(dc, style, StrokeKind::Graphic, configuration, || unsafe {
                    let radius = (style.stroke_width_mm * f64::from(configuration.dpi_x) / 25.4)
                        .max(1.0)
                        .round() as i32;
                    let center_x = x(configuration, center_mm.x_mm);
                    let center_y = y(configuration, center_mm.y_mm);
                    Ellipse(
                        dc,
                        center_x - radius,
                        center_y - radius,
                        center_x + radius,
                        center_y + radius,
                    );
                });
            }
            PrintRenderCommand::DrawText {
                position_mm,
                content,
                ..
            } => unsafe {
                SetBkMode(dc, TRANSPARENT as i32);
                SetTextColor(dc, RGB(0, 0, 0));
                let text = wide(content);
                if TextOutW(
                    dc,
                    x(configuration, position_mm.x_mm),
                    y(configuration, position_mm.y_mm),
                    text.as_ptr(),
                    text.len().saturating_sub(1) as i32,
                ) == 0
                {
                    return Err(last_error("Could not draw text on the Windows printer"));
                }
            },
        }
    }
    Ok(())
}

fn with_pen(
    dc: winapi::shared::windef::HDC,
    style: &kawacad_core::layers::LayerStyle,
    kind: StrokeKind,
    configuration: &PrinterConfiguration,
    draw: impl FnOnce(),
) {
    let width = (style.stroke_width_mm * f64::from(configuration.dpi_x) / 25.4)
        .max(1.0)
        .round() as i32;
    let pen_style = if matches!(kind, StrokeKind::Guide) {
        PS_DASH
    } else {
        match style.pattern {
            kawacad_core::layers::LinePattern::Solid => PS_SOLID,
            kawacad_core::layers::LinePattern::Dashed => PS_DASH,
            kawacad_core::layers::LinePattern::Dotted => winapi::um::wingdi::PS_DOT,
            kawacad_core::layers::LinePattern::Construction => winapi::um::wingdi::PS_DASHDOT,
        }
    };
    let pen = unsafe {
        CreatePen(
            pen_style as i32,
            width,
            RGB(
                color_channel(style.stroke.red),
                color_channel(style.stroke.green),
                color_channel(style.stroke.blue),
            ),
        )
    };
    if pen.is_null() {
        return;
    }
    let old = unsafe { SelectObject(dc, pen as _) };
    draw();
    unsafe {
        SelectObject(dc, old);
        DeleteObject(pen as _);
    }
}

fn color_channel(value: f32) -> u8 {
    (value.clamp(0.0, 1.0) * 255.0).round() as u8
}

fn x(configuration: &PrinterConfiguration, millimeters: f64) -> i32 {
    (f64::from(configuration.physical_width) / 2.0
        + millimeters * f64::from(configuration.dpi_x) / 25.4
        - f64::from(configuration.physical_offset_x))
    .round() as i32
}

fn y(configuration: &PrinterConfiguration, millimeters: f64) -> i32 {
    (f64::from(configuration.physical_height) / 2.0
        - millimeters * f64::from(configuration.dpi_y) / 25.4
        - f64::from(configuration.physical_offset_y))
    .round() as i32
}

fn wide(value: &str) -> Vec<u16> {
    OsStr::new(value)
        .encode_wide()
        .chain(iter::once(0))
        .collect()
}

fn wide_ptr_to_string(value: *const u16) -> String {
    let length = unsafe { (0..).take_while(|&index| *value.add(index) != 0).count() };
    String::from_utf16_lossy(unsafe { std::slice::from_raw_parts(value, length) })
}

fn last_error(prefix: &str) -> String {
    format!("{prefix} (Win32 error {})", unsafe {
        winapi::um::errhandlingapi::GetLastError()
    })
}
