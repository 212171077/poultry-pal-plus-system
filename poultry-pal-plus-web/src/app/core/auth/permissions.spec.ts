import { hasPermission, roleLabel } from './permissions';

describe('permissions', () => {
  it('lets owners, managers and admins manage the farm', () => {
    expect(hasPermission({ id: 'a', farmOwner: true }, 'FARM_MANAGER')).toBeTrue();
    expect(hasPermission({ id: 'b', roles: ['ROLE_FARM_MANAGER'] }, 'FARM_MANAGER')).toBeTrue();
    expect(hasPermission({ id: 'c', roles: ['ROLE_ADMIN'] }, 'FARM_MANAGER')).toBeTrue();
    expect(hasPermission({ id: 'd', roles: ['ROLE_USER'] }, 'FARM_MANAGER')).toBeFalse();
    expect(hasPermission(null, 'FARM_MANAGER')).toBeFalse();
  });

  it('keeps owner-only actions for the farm owner', () => {
    expect(hasPermission({ id: 'a', farmOwner: true }, 'FARM_OWNER')).toBeTrue();
    expect(hasPermission({ id: 'b', roles: ['ROLE_FARM_MANAGER'] }, 'FARM_OWNER')).toBeFalse();
  });

  it('limits system administration to ROLE_ADMIN, even for farm owners', () => {
    expect(hasPermission({ id: 'a', roles: ['ROLE_ADMIN'] }, 'SYSTEM_ADMIN')).toBeTrue();
    expect(hasPermission({ id: 'b', farmOwner: true, roles: [] }, 'SYSTEM_ADMIN')).toBeFalse();
    expect(hasPermission({ id: 'c', roles: ['ROLE_FARM_MANAGER'] }, 'SYSTEM_ADMIN')).toBeFalse();
    expect(hasPermission(null, 'SYSTEM_ADMIN')).toBeFalse();
  });

  it('requires an explicit grant for production, except for the farm owner', () => {
    expect(hasPermission({ id: 'a', farmOwner: true }, 'PRODUCTION_MANAGE')).toBeTrue();
    expect(
      hasPermission({ id: 'b', permissions: ['PRODUCTION_MANAGE'] }, 'PRODUCTION_MANAGE'),
    ).toBeTrue();
    expect(
      hasPermission({ id: 'c', roles: ['ROLE_FARM_MANAGER'] }, 'PRODUCTION_MANAGE'),
    ).toBeFalse();
    expect(hasPermission({ id: 'd', roles: ['ROLE_ADMIN'] }, 'PRODUCTION_MANAGE')).toBeFalse();
    expect(hasPermission(null, 'PRODUCTION_MANAGE')).toBeFalse();
  });

  it('describes the role for the account menu', () => {
    expect(roleLabel({ id: 'a', farmOwner: true })).toBe('Farm owner');
    expect(roleLabel({ id: 'b', roles: ['ROLE_FARM_MANAGER'] })).toBe('Farm manager');
    expect(roleLabel({ id: 'c', roles: [] })).toBe('Farm worker');
  });
});
