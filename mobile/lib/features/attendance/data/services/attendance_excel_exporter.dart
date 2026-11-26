import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/attendance_entities.dart';
import '../../domain/services/class_keys.dart';

/// Builds a styled, column-aligned `.xlsx` attendance register matching the
/// department register layout (University/Course/Teacher title rows + Roll,
/// Name, per-date `P`/`A` history, and summary totals).
class AttendanceExcelExporter {
  AttendanceExcelExporter._();

  static const String universityName = 'Jagannath University';
  static const String departmentName =
      'Department of Computer Science & Engineering';
  static const String universityHeader = '$universityName — $departmentName';

  /// Formats `yyyy-MM-dd` as `d.M.yy` (e.g. `2026-01-26` -> `26.1.26`, `2026-11-26` -> `26.11.26`).
  static String formatShortDate(String dateKey) =>
      CourseAttendanceReport.formatShortDate(dateKey);

  /// Generates valid `.xlsx` bytes for [report] with every row aligned to
  /// `[Sl, Roll, Name, ...classDates, Present, Held, %]`.
  static Uint8List buildBytes(CourseAttendanceReport report) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    if (defaultSheet != 'Attendance') {
      excel.rename(defaultSheet, 'Attendance');
    }
    final sheet = excel['Attendance'];

    final dates = [...report.classDates]..sort();
    // Columns: Sl, Roll, Name, [classes...], Present, Absent, %, Eligible
    final summaryStart = 3 + dates.length;
    final lastCol = summaryStart + 3;

    final thin = Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black);
    final none = Border(borderStyle: BorderStyle.None);
    final white = ExcelColor.white;
    final shade = ExcelColor.fromHexString('FFFDE2E2'); // below 75 %
    final headerFill = ExcelColor.fromHexString('FFE9ECEF');
    const pct = CustomNumericNumFormat(formatCode: '0.0%');

    CellStyle style({
      bool bold = false,
      int size = 10,
      HorizontalAlign align = HorizontalAlign.Center,
      ExcelColor? fill,
      bool boxed = true,
      NumFormat? format,
      ExcelColor? color,
    }) =>
        CellStyle(
          bold: bold,
          fontSize: size,
          fontColorHex: color ?? ExcelColor.black,
          backgroundColorHex: fill ?? white,
          horizontalAlign: align,
          verticalAlign: VerticalAlign.Center,
          leftBorder: boxed ? thin : none,
          rightBorder: boxed ? thin : none,
          topBorder: boxed ? thin : none,
          bottomBorder: boxed ? thin : none,
          numberFormat: format ?? NumFormat.standard_0,
        );

    // ── Title block: one clean box, no inner grid lines (fixes 1–3) ─────
    final banner = <(String, int, bool, double)>[
      (universityName, 13, true, 22),
      (departmentName, 11, true, 18),
      (report.courseLine, 10, true, 17),
      (report.detailsLine, 10, false, 17),
      if (report.generatedLine != null) (report.generatedLine!, 9, false, 15),
    ];
    for (var r = 0; r < banner.length; r++) {
      final (text, size, bold, height) = banner[r];
      final first = r == 0, last = r == banner.length - 1;
      // Text first, then the style (setting a value afterwards resets it).
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value = TextCellValue(text);
      for (var c = 0; c <= lastCol; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = CellStyle(
          bold: bold,
          fontSize: size,
          fontColorHex: r >= 3 ? ExcelColor.fromHexString('FF333333') : ExcelColor.black,
          backgroundColorHex: white,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: c == 0 ? thin : none,
          rightBorder: c == lastCol ? thin : none,
          topBorder: first ? thin : none,
          bottomBorder: last ? thin : none,
        );
      }
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
        CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: r),
      );
      sheet.setRowHeight(r, height);
    }

    // ── Table header (right under the title box) ───────────────────────
    final headerRowIdx = banner.length;
    sheet.setRowHeight(headerRowIdx, 22);
    void header(int col, String label, {bool left = false}) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: headerRowIdx))
        ..value = TextCellValue(label)
        ..cellStyle = style(bold: true, fill: headerFill, align: left ? HorizontalAlign.Left : HorizontalAlign.Center);
    }

    header(0, 'Sl');
    header(1, 'Roll', left: true);
    header(2, 'Name', left: true);
    final labels = ClassKeys.labels(dates, formatShortDate);
    for (var d = 0; d < dates.length; d++) {
      header(3 + d, labels[d]);
    }
    header(summaryStart, 'Present');
    header(summaryStart + 1, 'Absent');
    header(summaryStart + 2, '%');
    header(summaryStart + 3, 'Eligible');

    // ── Students, by roll ───────────────────────────────────────────────
    final sortedRows = [...report.rows]
      ..sort((a, b) => a.studentRoll.toLowerCase().compareTo(b.studentRoll.toLowerCase()));

    for (var i = 0; i < sortedRows.length; i++) {
      final r = sortedRows[i];
      final rowIdx = headerRowIdx + 1 + i;
      final absentCount = (r.held - r.attended).clamp(0, r.held);
      final fill = r.isBelow75 ? shade : white; // fix 5
      CellStyle center() => style(fill: fill);
      CellStyle leftS() => style(fill: fill, align: HorizontalAlign.Left);
      void put(int col, CellValue v, CellStyle st) =>
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx))
            ..value = v
            ..cellStyle = st;

      sheet.setRowHeight(rowIdx, 19);
      put(0, IntCellValue(i + 1), center());
      put(1, TextCellValue(r.studentRoll), leftS());
      put(2, TextCellValue(r.studentName), leftS());
      for (var d = 0; d < dates.length; d++) {
        put(3 + d, TextCellValue(r.presentDates.contains(dates[d]) ? 'P' : 'A'), center());
      }
      put(summaryStart, IntCellValue(r.attended), center());
      put(summaryStart + 1, IntCellValue(absentCount), center());
      // Real percentage (fix 6); "—" while no class has been held (fix 4).
      if (r.held == 0) {
        put(summaryStart + 2, TextCellValue('—'), center());
      } else {
        put(summaryStart + 2, DoubleCellValue(double.parse((r.percentage / 100).toStringAsFixed(4))), style(fill: fill, format: pct));
      }
      put(
        summaryStart + 3,
        TextCellValue(CourseAttendanceReport.eligibleText(r)),
        style(fill: fill, bold: r.isBelow75, color: r.isBelow75 ? ExcelColor.fromHexString('FFB91C1C') : null),
      );
    }

    // ── Totals (fix 9) ──────────────────────────────────────────────────
    final totalsRow = headerRowIdx + 1 + sortedRows.length;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalsRow)).value = TextCellValue(report.summaryLine);
    for (var c = 0; c <= lastCol; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalsRow)).cellStyle =
          style(bold: true, fill: headerFill, align: HorizontalAlign.Left);
    }
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalsRow),
      CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: totalsRow),
    );
    sheet.setRowHeight(totalsRow, 20);

    // ── Column widths (no truncation / ####) ────────────────────────────
    var maxRollLen = 12;
    var maxNameLen = 22;
    for (final r in sortedRows) {
      if (r.studentRoll.length + 3 > maxRollLen) maxRollLen = r.studentRoll.length + 3;
      if (r.studentName.length + 4 > maxNameLen) maxNameLen = r.studentName.length + 4;
    }
    // The title lines must fit on one line: with few classes the table is
    // narrow, so the Name column takes up the slack (fix 1).
    final rollW = maxRollLen.clamp(14, 24).toDouble();
    var nameW = maxNameLen.clamp(24, 42).toDouble();
    final longest = [report.courseLine, report.detailsLine, report.summaryLine]
        .map((t) => t.length)
        .reduce((a, b) => a > b ? a : b);
    final tableW = 6 + rollW + nameW + dates.length * 10 + 9 + 8 + 9 + 9;
    if (tableW < longest + 6) nameW += longest + 6 - tableW;
    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, rollW);
    sheet.setColumnWidth(2, nameW);
    for (var d = 0; d < dates.length; d++) {
      sheet.setColumnWidth(3 + d, 10);
    }
    sheet.setColumnWidth(summaryStart, 9);
    sheet.setColumnWidth(summaryStart + 1, 8);
    sheet.setColumnWidth(summaryStart + 2, 9);
    sheet.setColumnWidth(summaryStart + 3, 9);

    final raw = excel.save();
    if (raw == null) {
      throw StateError('Failed to encode Excel attendance sheet.');
    }
    return Uint8List.fromList(raw);
  }

  /// Writes the `.xlsx` file to temp storage and triggers the OS share/save sheet.
  static Future<void> exportAndShare(CourseAttendanceReport report) async {
    final bytes = buildBytes(report);
    final safeCode = report.courseCode
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final fileName = '${safeCode.isEmpty ? 'course' : safeCode}_attendance.xlsx';
    const mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

    // Web has no file system: share / download straight from memory.
    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: mime, name: fileName)],
          fileNameOverrides: [fileName],
          subject: '${report.courseCode} Attendance Report',
        ),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: fileName,
          ),
        ],
        subject: '${report.courseCode} Attendance Report',
      ),
    );
  }
}
