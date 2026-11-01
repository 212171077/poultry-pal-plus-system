import { toCsv, toExcelXml } from './table-export';

describe('table export', () => {
  const table = {
    name: 'Sales',
    headers: ['Buyer', 'Total'],
    rows: [
      ['Smith, "Bob"', 12.5],
      ['=HYPERLINK("x")', null],
    ],
  };

  it('writes RFC 4180 CSV and neutralises formulas', () => {
    expect(toCsv(table)).toBe(
      '\uFEFFBuyer,Total\r\n"Smith, ""Bob""",12.5\r\n"\'=HYPERLINK(""x"")",\r\n',
    );
  });

  it('writes an Excel workbook with typed cells and safe sheet names', () => {
    const xml = toExcelXml([
      { ...table, name: 'A/B: <sales>' },
      { ...table, name: 'A/B: <sales>' },
    ]);
    expect(xml).toContain('<Data ss:Type="Number">12.5</Data>');
    expect(xml).toContain('Smith, &quot;Bob&quot;');
    expect(xml.match(/<Worksheet /g)?.length).toBe(2);
    expect(xml).not.toContain('A/B');
  });
});
