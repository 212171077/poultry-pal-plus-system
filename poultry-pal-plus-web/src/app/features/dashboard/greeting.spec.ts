import { greetingFor } from './greeting';

describe('greetingFor', () => {
  it('greets by time of day', () => {
    expect(greetingFor(6)).toBe('Good morning');
    expect(greetingFor(13)).toBe('Good afternoon');
    expect(greetingFor(20)).toBe('Good evening');
  });
});
