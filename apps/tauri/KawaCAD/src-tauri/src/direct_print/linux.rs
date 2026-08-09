use super::{
    DirectPrintArtifact, DirectPrintAvailability, DirectPrintAvailabilityStatus,
    DirectPrintOptions, DirectPrinter, InspectPrinterRequest, PreparedDirectPrint,
    PrinterInspection,
};
use kawacad_core::output::PrintableAreaMm;
use libloading::Library;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_uint};
use std::ptr;
use std::sync::OnceLock;

const A4_MEDIA: &str = "iso_a4_210x297mm";
const HTTP_STATUS_CONTINUE: c_int = 100;
const IPP_STATUS_OK: c_int = 0;
const CUPS_MEDIA_FLAGS_EXACT: c_uint = 0x0000_0004;

#[repr(C)]
struct CupsOption {
    name: *mut c_char,
    value: *mut c_char,
}

#[repr(C)]
struct CupsDest {
    name: *mut c_char,
    instance: *mut c_char,
    is_default: c_int,
    num_options: c_int,
    options: *mut CupsOption,
}

#[repr(C)]
struct CupsSize {
    media: [c_char; 128],
    width: c_int,
    length: c_int,
    bottom: c_int,
    left: c_int,
    right: c_int,
    top: c_int,
}

enum Http {}
enum DestInfo {}

type CupsGetDests2 = unsafe extern "C" fn(*mut Http, *mut *mut CupsDest) -> c_int;
type CupsFreeDests = unsafe extern "C" fn(c_int, *mut CupsDest);
type CupsGetNamedDest =
    unsafe extern "C" fn(*mut Http, *const c_char, *const c_char) -> *mut CupsDest;
type CupsCopyDestInfo = unsafe extern "C" fn(*mut Http, *mut CupsDest) -> *mut DestInfo;
type CupsFreeDestInfo = unsafe extern "C" fn(*mut DestInfo);
type CupsCheckDestSupported = unsafe extern "C" fn(
    *mut Http,
    *mut CupsDest,
    *mut DestInfo,
    *const c_char,
    *const c_char,
) -> c_int;
type CupsGetDestMediaByName = unsafe extern "C" fn(
    *mut Http,
    *mut CupsDest,
    *mut DestInfo,
    *const c_char,
    c_uint,
    *mut CupsSize,
) -> c_int;
type CupsAddOption =
    unsafe extern "C" fn(*const c_char, *const c_char, c_int, *mut *mut CupsOption) -> c_int;
type CupsFreeOptions = unsafe extern "C" fn(c_int, *mut CupsOption);
type CupsCopyDestConflicts = unsafe extern "C" fn(
    *mut Http,
    *mut CupsDest,
    *mut DestInfo,
    c_int,
    *mut CupsOption,
    *const c_char,
    *const c_char,
    *mut c_int,
    *mut *mut CupsOption,
    *mut c_int,
    *mut *mut CupsOption,
) -> c_int;
type CupsCreateDestJob = unsafe extern "C" fn(
    *mut Http,
    *mut CupsDest,
    *mut DestInfo,
    *mut c_int,
    *const c_char,
    c_int,
    *mut CupsOption,
) -> c_int;
type CupsStartDestDocument = unsafe extern "C" fn(
    *mut Http,
    *mut CupsDest,
    *mut DestInfo,
    c_int,
    *const c_char,
    *const c_char,
    c_int,
    *mut CupsOption,
    c_int,
) -> c_int;
type CupsWriteRequestData = unsafe extern "C" fn(*mut Http, *const c_char, usize) -> c_int;
type CupsFinishDestDocument =
    unsafe extern "C" fn(*mut Http, *mut CupsDest, *mut DestInfo) -> c_int;
type CupsCancelDestJob = unsafe extern "C" fn(*mut Http, *mut CupsDest, c_int) -> c_int;

struct Cups {
    get_dests2: CupsGetDests2,
    free_dests: CupsFreeDests,
    get_named_dest: CupsGetNamedDest,
    copy_dest_info: CupsCopyDestInfo,
    free_dest_info: CupsFreeDestInfo,
    check_dest_supported: CupsCheckDestSupported,
    get_dest_media_by_name: CupsGetDestMediaByName,
    add_option: CupsAddOption,
    free_options: CupsFreeOptions,
    copy_dest_conflicts: CupsCopyDestConflicts,
    create_dest_job: CupsCreateDestJob,
    start_dest_document: CupsStartDestDocument,
    write_request_data: CupsWriteRequestData,
    finish_dest_document: CupsFinishDestDocument,
    cancel_dest_job: CupsCancelDestJob,
}

static CUPS_LIBRARY: OnceLock<Result<&'static Library, String>> = OnceLock::new();

impl Cups {
    fn load() -> Result<Self, String> {
        let library = cups_library()?;
        unsafe {
            Ok(Self {
                get_dests2: symbol(library, b"cupsGetDests2\0")?,
                free_dests: symbol(library, b"cupsFreeDests\0")?,
                get_named_dest: symbol(library, b"cupsGetNamedDest\0")?,
                copy_dest_info: symbol(library, b"cupsCopyDestInfo\0")?,
                free_dest_info: symbol(library, b"cupsFreeDestInfo\0")?,
                check_dest_supported: symbol(library, b"cupsCheckDestSupported\0")?,
                get_dest_media_by_name: symbol(library, b"cupsGetDestMediaByName\0")?,
                add_option: symbol(library, b"cupsAddOption\0")?,
                free_options: symbol(library, b"cupsFreeOptions\0")?,
                copy_dest_conflicts: symbol(library, b"cupsCopyDestConflicts\0")?,
                create_dest_job: symbol(library, b"cupsCreateDestJob\0")?,
                start_dest_document: symbol(library, b"cupsStartDestDocument\0")?,
                write_request_data: symbol(library, b"cupsWriteRequestData\0")?,
                finish_dest_document: symbol(library, b"cupsFinishDestDocument\0")?,
                cancel_dest_job: symbol(library, b"cupsCancelDestJob\0")?,
            })
        }
    }
}

fn cups_library() -> Result<&'static Library, String> {
    match CUPS_LIBRARY.get_or_init(|| {
        // libloading keeps CUPS optional. Keep a successful load alive until process exit: CUPS
        // retains process-global state that is not safe to tear down after each adapter call.
        unsafe { Library::new("libcups.so.2") }
            .or_else(|_| unsafe { Library::new("libcups.so") })
            .map(|library| -> &'static Library { Box::leak(Box::new(library)) })
            .map_err(|error| format!("CUPS is not available: {error}"))
    }) {
        Ok(library) => Ok(*library),
        Err(error) => Err(error.clone()),
    }
}

unsafe fn symbol<T: Copy>(library: &Library, name: &[u8]) -> Result<T, String> {
    library
        .get::<T>(name)
        .map(|symbol| *symbol)
        .map_err(|error| {
            format!(
                "CUPS does not provide {}: {error}",
                String::from_utf8_lossy(name)
            )
        })
}

pub(super) fn availability() -> DirectPrintAvailability {
    match list_printers() {
        Ok(printers) if !printers.is_empty() => DirectPrintAvailability {
            status: DirectPrintAvailabilityStatus::Available,
            reason: None,
        },
        Ok(_) => DirectPrintAvailability {
            status: DirectPrintAvailabilityStatus::Unavailable,
            reason: Some("CUPS does not currently provide a printer".to_owned()),
        },
        Err(reason) => DirectPrintAvailability {
            status: DirectPrintAvailabilityStatus::Unavailable,
            reason: Some(reason),
        },
    }
}

pub(super) fn list_printers() -> Result<Vec<DirectPrinter>, String> {
    let cups = Cups::load()?;
    let mut destinations = ptr::null_mut();
    let count = unsafe { (cups.get_dests2)(ptr::null_mut(), &mut destinations) };
    if count < 0 {
        return Err("Could not enumerate CUPS printers".to_owned());
    }
    let result = (0..count as usize)
        .filter_map(|index| {
            let destination = unsafe { &*destinations.add(index) };
            (!destination.name.is_null()).then(|| {
                let name = string_from_ptr(destination.name);
                let id = if destination.instance.is_null() {
                    name.clone()
                } else {
                    format!("{name}/{}", string_from_ptr(destination.instance))
                };
                DirectPrinter {
                    id,
                    display_name: name,
                    selectable: true,
                }
            })
        })
        .collect();
    unsafe { (cups.free_dests)(count, destinations) };
    Ok(result)
}

pub(super) fn inspect_printer(
    request: &InspectPrinterRequest,
) -> Result<PrinterInspection, String> {
    let cups = Cups::load()?;
    let destination = named_destination(&cups, &request.printer_id)?;
    let info = unsafe { (cups.copy_dest_info)(ptr::null_mut(), destination) };
    if info.is_null() {
        unsafe { (cups.free_dests)(1, destination) };
        return Err("Could not inspect the selected CUPS printer".to_owned());
    }
    let result = inspect_destination(
        &cups,
        destination,
        info,
        &request.printer_id,
        &request.options,
    );
    unsafe {
        (cups.free_dest_info)(info);
        (cups.free_dests)(1, destination);
    }
    result
}

fn inspect_destination(
    cups: &Cups,
    destination: *mut CupsDest,
    info: *mut DestInfo,
    printer_id: &str,
    options: &DirectPrintOptions,
) -> Result<PrinterInspection, String> {
    let supported = [
        ("media", A4_MEDIA),
        ("sides", "one-sided"),
        ("print-scaling", "none"),
        ("number-up", "1"),
        ("document-format", "application/pdf"),
        ("orientation-requested", orientation_requested(options)?),
    ];
    for (name, value) in supported {
        let name = cstring(name)?;
        let value = cstring(value)?;
        if unsafe {
            (cups.check_dest_supported)(
                ptr::null_mut(),
                destination,
                info,
                name.as_ptr(),
                value.as_ptr(),
            )
        } == 0
        {
            return Ok(PrinterInspection {
                printer_id: printer_id.to_owned(),
                selectable: false,
                printable_area_mm: None,
                reason: Some(
                    "The printer does not accept required A4 100% simplex PDF settings".to_owned(),
                ),
                capability_fingerprint: None,
            });
        }
    }
    let (option_count, required_options) = required_options(cups, options)?;
    let conflicts = validate_combination(cups, destination, info, option_count, required_options);
    unsafe { (cups.free_options)(option_count, required_options) };
    if let Err(reason) = conflicts {
        return Ok(unsupported_printer(printer_id, reason));
    }
    let mut media = unsafe { std::mem::zeroed::<CupsSize>() };
    let media_name = cstring(A4_MEDIA)?;
    if unsafe {
        (cups.get_dest_media_by_name)(
            ptr::null_mut(),
            destination,
            info,
            media_name.as_ptr(),
            CUPS_MEDIA_FLAGS_EXACT,
            &mut media,
        )
    } == 0
    {
        return Ok(PrinterInspection {
            printer_id: printer_id.to_owned(),
            selectable: false,
            printable_area_mm: None,
            reason: Some("The printer did not provide an exact A4 printable area".to_owned()),
            capability_fingerprint: None,
        });
    }
    let portrait_area = PrintableAreaMm {
        left_mm: f64::from(media.left) / 100.0 - f64::from(media.width) / 200.0,
        right_mm: f64::from(media.width - media.right) / 100.0 - f64::from(media.width) / 200.0,
        top_mm: f64::from(media.length - media.top) / 100.0 - f64::from(media.length) / 200.0,
        bottom_mm: f64::from(media.bottom) / 100.0 - f64::from(media.length) / 200.0,
    };
    let printable_area_mm = match options.orientation.as_str() {
        "portrait" => portrait_area,
        "landscape" => PrintableAreaMm {
            left_mm: portrait_area.bottom_mm,
            right_mm: portrait_area.top_mm,
            top_mm: -portrait_area.left_mm,
            bottom_mm: -portrait_area.right_mm,
        },
        _ => return Err("Direct printing requires a valid A4 orientation".to_owned()),
    };
    Ok(PrinterInspection {
        printer_id: printer_id.to_owned(),
        selectable: true,
        printable_area_mm: Some(printable_area_mm),
        reason: None,
        capability_fingerprint: Some(format!(
            "cups:{printer_id}:{}:{}:{}:{}:{}:{}",
            media.width, media.length, media.left, media.right, media.top, media.bottom
        )),
    })
}

pub(super) fn send(prepared: &PreparedDirectPrint) -> Result<(), String> {
    let inspection = inspect_printer(&InspectPrinterRequest {
        printer_id: prepared.printer_id.clone(),
        options: prepared.options.clone(),
    })?;
    if !inspection.selectable
        || inspection.capability_fingerprint.as_deref() != Some(&prepared.capability_fingerprint)
    {
        return Err(
            "Prepared direct print is stale because printer capabilities changed".to_owned(),
        );
    }
    let DirectPrintArtifact::LinuxPdf(pdf) = &prepared.artifact else {
        return Err("Prepared direct print has an invalid Linux artifact".to_owned());
    };
    let cups = Cups::load()?;
    let destination = named_destination(&cups, &prepared.printer_id)?;
    let info = unsafe { (cups.copy_dest_info)(ptr::null_mut(), destination) };
    if info.is_null() {
        unsafe { (cups.free_dests)(1, destination) };
        return Err("Could not open the selected CUPS printer".to_owned());
    }
    let result = submit_pdf(&cups, destination, info, pdf, &prepared.options);
    unsafe {
        (cups.free_dest_info)(info);
        (cups.free_dests)(1, destination);
    }
    result
}

fn submit_pdf(
    cups: &Cups,
    destination: *mut CupsDest,
    info: *mut DestInfo,
    pdf: &[u8],
    direct_print_options: &DirectPrintOptions,
) -> Result<(), String> {
    let (option_count, options) = required_options(cups, direct_print_options)?;
    let result = (|| {
        let mut job_id = 0;
        let title = cstring("KawaCAD")?;
        let status = unsafe {
            (cups.create_dest_job)(
                ptr::null_mut(),
                destination,
                info,
                &mut job_id,
                title.as_ptr(),
                option_count,
                options,
            )
        };
        if status != IPP_STATUS_OK {
            return Err("CUPS rejected the fixed direct-print settings".to_owned());
        }
        let document_name = cstring("KawaCAD.pdf")?;
        let mime_type = cstring("application/pdf")?;
        let result = unsafe {
            (cups.start_dest_document)(
                ptr::null_mut(),
                destination,
                info,
                job_id,
                document_name.as_ptr(),
                mime_type.as_ptr(),
                option_count,
                options,
                1,
            )
        };
        if result != HTTP_STATUS_CONTINUE {
            unsafe { (cups.cancel_dest_job)(ptr::null_mut(), destination, job_id) };
            return Err("CUPS rejected the direct-print PDF document".to_owned());
        }
        if unsafe { (cups.write_request_data)(ptr::null_mut(), pdf.as_ptr().cast(), pdf.len()) }
            != HTTP_STATUS_CONTINUE
        {
            unsafe { (cups.cancel_dest_job)(ptr::null_mut(), destination, job_id) };
            return Err("Could not send the direct-print PDF data to CUPS".to_owned());
        }
        if unsafe { (cups.finish_dest_document)(ptr::null_mut(), destination, info) }
            != IPP_STATUS_OK
        {
            unsafe { (cups.cancel_dest_job)(ptr::null_mut(), destination, job_id) };
            return Err("CUPS did not accept the direct-print job".to_owned());
        }
        Ok(())
    })();
    unsafe { (cups.free_options)(option_count, options) };
    result
}

fn required_options(
    cups: &Cups,
    options: &DirectPrintOptions,
) -> Result<(c_int, *mut CupsOption), String> {
    let mut raw_options = ptr::null_mut();
    let mut option_count = 0;
    for (name, value) in [
        ("media", A4_MEDIA),
        ("sides", "one-sided"),
        ("print-scaling", "none"),
        ("number-up", "1"),
        ("ipp-attribute-fidelity", "true"),
        ("orientation-requested", orientation_requested(options)?),
    ] {
        let name = cstring(name)?;
        let value = cstring(value)?;
        option_count = unsafe {
            (cups.add_option)(
                name.as_ptr(),
                value.as_ptr(),
                option_count,
                &mut raw_options,
            )
        };
    }
    Ok((option_count, raw_options))
}

fn validate_combination(
    cups: &Cups,
    destination: *mut CupsDest,
    info: *mut DestInfo,
    option_count: c_int,
    options: *mut CupsOption,
) -> Result<(), String> {
    let mut conflicts = ptr::null_mut();
    let mut resolved = ptr::null_mut();
    let mut conflict_count = 0;
    let mut resolved_count = 0;
    let result = unsafe {
        (cups.copy_dest_conflicts)(
            ptr::null_mut(),
            destination,
            info,
            option_count,
            options,
            ptr::null(),
            ptr::null(),
            &mut conflict_count,
            &mut conflicts,
            &mut resolved_count,
            &mut resolved,
        )
    };
    unsafe {
        (cups.free_options)(conflict_count, conflicts);
        (cups.free_options)(resolved_count, resolved);
    }
    match result {
        0 => Ok(()),
        1 => Err("The required A4, 100%, simplex, 1-up PDF settings conflict".to_owned()),
        _ => Err("Could not validate the required CUPS print settings".to_owned()),
    }
}

fn orientation_requested(options: &DirectPrintOptions) -> Result<&'static str, String> {
    match options.orientation.as_str() {
        "portrait" => Ok("3"),
        "landscape" => Ok("4"),
        _ => Err("Direct printing requires a valid A4 orientation".to_owned()),
    }
}

fn unsupported_printer(printer_id: &str, reason: String) -> PrinterInspection {
    PrinterInspection {
        printer_id: printer_id.to_owned(),
        selectable: false,
        printable_area_mm: None,
        reason: Some(reason),
        capability_fingerprint: None,
    }
}

fn named_destination(cups: &Cups, printer_id: &str) -> Result<*mut CupsDest, String> {
    let (name, instance) = printer_id
        .split_once('/')
        .map_or((printer_id, None), |(name, instance)| {
            (name, Some(instance))
        });
    let name = cstring(name)?;
    let instance = instance.map(cstring).transpose()?;
    let destination = unsafe {
        (cups.get_named_dest)(
            ptr::null_mut(),
            name.as_ptr(),
            instance
                .as_ref()
                .map_or(ptr::null(), |value| value.as_ptr()),
        )
    };
    if destination.is_null() {
        Err("The selected CUPS printer is unavailable".to_owned())
    } else {
        Ok(destination)
    }
}

fn cstring(value: &str) -> Result<CString, String> {
    CString::new(value).map_err(|_| "Printer settings contain an embedded NUL byte".to_owned())
}

fn string_from_ptr(value: *const c_char) -> String {
    unsafe { CStr::from_ptr(value) }
        .to_string_lossy()
        .into_owned()
}
