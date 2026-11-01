export type CellValue = string | number | null | undefined;

export interface ExportTable {
  readonly name: string;
  readonly headers: readonly string[];
  readonly rows: readonly (readonly CellValue[])[];
}

/** RFC 4180 CSV. A leading BOM lets Excel read UTF-8, and cells that start with a formula character are neutralised. */
export function toCsv(table: ExportTable): string {
  const cell = (value: CellValue): string => {
    if (value === null || value === undefined) return '';
    let text = String(value);
    if (typeof value === 'string' && /^[=+\-@\t\r]/.test(text)) text = `'${text}`;
    return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
  };
  const lines = [table.headers, ...table.rows].map((row) => row.map(cell).join(','));
  return `\uFEFF${lines.join('\r\n')}\r\n`;
}

const escapeXml = (text: string): string =>
  text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    // Characters XML 1.0 forbids.
    // eslint-disable-next-line no-control-regex
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '');

/** Excel 2003 XML workbook (opens in Excel and LibreOffice) with one worksheet per table. */
export function toExcelXml(tables: readonly ExportTable[]): string {
  const cell = (value: CellValue): string => {
    if (value === null || value === undefined || value === '') return '<Cell/>';
    if (typeof value === 'number' && Number.isFinite(value)) {
      return `<Cell><Data ss:Type="Number">${value}</Data></Cell>`;
    }
    return `<Cell><Data ss:Type="String">${escapeXml(String(value))}</Data></Cell>`;
  };
  const row = (values: readonly CellValue[], style = ''): string =>
    `<Row${style}>${values.map(cell).join('')}</Row>`;
  const used = new Set<string>();
  const sheets = tables.map((table, index) => {
    // Worksheet names: max 31 chars, no : \ / ? * [ ], unique.
    let name =
      table.name
        .replace(/[:\\/?*[\]]/g, ' ')
        .slice(0, 31)
        .trim() || `Sheet${index + 1}`;
    while (used.has(name.toLowerCase())) name = `${name.slice(0, 28)}-${index + 1}`;
    used.add(name.toLowerCase());
    return (
      `<Worksheet ss:Name="${escapeXml(name)}"><Table>` +
      row(table.headers, ' ss:StyleID="header"') +
      table.rows.map((values) => row(values)).join('') +
      '</Table></Worksheet>'
    );
  });
  return (
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<?mso-application progid="Excel.Sheet"?>' +
    '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" ' +
    'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">' +
    '<Styles><Style ss:ID="header"><Font ss:Bold="1"/></Style></Styles>' +
    sheets.join('') +
    '</Workbook>'
  );
}

export function fileSafe(name: string): string {
  return (
    name
      .trim()
      .replace(/[^\w-]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .toLowerCase() || 'export'
  );
}

/** Saves text or binary content as a file download. */
export function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function downloadCsv(table: ExportTable, filename: string): void {
  downloadBlob(new Blob([toCsv(table)], { type: 'text/csv;charset=utf-8' }), `${filename}.csv`);
}

export function downloadExcel(tables: readonly ExportTable[], filename: string): void {
  downloadBlob(
    new Blob([toExcelXml(tables)], { type: 'application/vnd.ms-excel;charset=utf-8' }),
    `${filename}.xls`,
  );
}
