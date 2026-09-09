import 'package:excel/excel.dart';

import 'admin_service.dart';

/// Builds a multi-sheet .xlsx workbook from the same data the admin
/// analytics tab and CSV export already fetch. Pure Dart — no
/// platform-specific code; downloading the resulting bytes is handled
/// separately by `file_download_service.dart`.
class AdminExcelExportService {
  List<int> buildWorkbookBytes({
    required AdminAnalytics analytics,
    required List<PatientRecord> records,
  }) {
    final workbook = Excel.createExcel();
    final defaultSheetName = workbook.getDefaultSheet();

    _writeSummarySheet(workbook['Summary'], analytics);
    _writePatientRecordsSheet(workbook['Patient Records'], records);
    _writeResponseTimesSheet(workbook['Response Times'], analytics);

    // Drop the blank default sheet Excel.createExcel() seeds (e.g. 'Sheet1')
    // now that at least one real sheet exists — a workbook can't have zero
    // sheets, so this must happen after the sheets above are created.
    if (defaultSheetName != null && defaultSheetName != 'Summary') {
      workbook.delete(defaultSheetName);
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('Failed to encode Excel workbook');
    }
    return bytes;
  }

  void _writeSummarySheet(Sheet sheet, AdminAnalytics a) {
    sheet.appendRow([TextCellValue('ERAMS Analytics Summary')]);
    sheet.appendRow([
      TextCellValue('Generated'),
      TextCellValue(DateTime.now().toIso8601String()),
    ]);
    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('KPI'), TextCellValue('Value')]);
    sheet.appendRow(
        [TextCellValue('Total Incidents'), IntCellValue(a.totalIncidents)]);
    sheet.appendRow(
        [TextCellValue('Avg Response'), TextCellValue(a.avgResponseFormatted)]);
    sheet.appendRow([TextCellValue('Calls Today'), IntCellValue(a.callsToday)]);
    sheet.appendRow([
      TextCellValue('Completion Rate'),
      TextCellValue(a.completionRateFormatted),
    ]);
    sheet.appendRow([]);

    _writeCountMapSection(sheet, 'Incidents by Status', a.countByStatus);
    _writeCountMapSection(sheet, 'Incidents by Hospital', a.countByHospital);
    _writeCountMapSection(
        sheet, 'Incidents by Emergency Type', a.countByEmergencyType);
    _writeCountMapSection(sheet, 'Fleet Status', a.fleetStatusCounts);
  }

  void _writeCountMapSection(
      Sheet sheet, String title, Map<String, int> counts) {
    sheet.appendRow([TextCellValue(title)]);
    sheet.appendRow([TextCellValue('Category'), TextCellValue('Count')]);
    for (final entry in counts.entries) {
      sheet.appendRow(
          [TextCellValue(entry.key), IntCellValue(entry.value)]);
    }
    sheet.appendRow([]);
  }

  void _writePatientRecordsSheet(Sheet sheet, List<PatientRecord> records) {
    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Patient'),
      TextCellValue('Phone'),
      TextCellValue('Emergency'),
      TextCellValue('Location'),
      TextCellValue('Status'),
      TextCellValue('Priority'),
      TextCellValue('Ambulance'),
      TextCellValue('Hospital'),
      TextCellValue('Created'),
      TextCellValue('Dispatched'),
      TextCellValue('Arrived'),
      TextCellValue('Completed'),
      TextCellValue('Response Time'),
    ]);
    for (final r in records) {
      sheet.appendRow([
        TextCellValue(r.incidentId),
        TextCellValue(r.patientName),
        TextCellValue(r.patientPhone),
        TextCellValue(r.natureOfEmergency),
        TextCellValue(r.locationDescription),
        TextCellValue(r.status),
        TextCellValue(r.priority),
        TextCellValue(r.ambulancePlate ?? ''),
        TextCellValue(r.hospitalName ?? ''),
        TextCellValue(r.createdAt.toIso8601String()),
        TextCellValue(r.dispatchedAt?.toIso8601String() ?? ''),
        TextCellValue(r.arrivedAt?.toIso8601String() ?? ''),
        TextCellValue(r.completedAt?.toIso8601String() ?? ''),
        TextCellValue(r.responseTime ?? ''),
      ]);
    }
  }

  void _writeResponseTimesSheet(Sheet sheet, AdminAnalytics a) {
    sheet.appendRow([TextCellValue('Incident'), TextCellValue('Minutes')]);
    for (final rt in a.recentResponseTimes) {
      sheet.appendRow(
          [TextCellValue(rt.label), DoubleCellValue(rt.minutes)]);
    }
  }
}
