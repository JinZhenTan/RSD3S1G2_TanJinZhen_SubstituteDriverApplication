enum UserRole { user, driver, serviceStaff }

String userRoleLabel(UserRole role) {
  switch (role) {
    case UserRole.user:
      return 'Book a driver / car service';
    case UserRole.driver:
      return 'Work as a substitute driver';
    case UserRole.serviceStaff:
      return 'Work as a car service partner';
  }
}

String userRoleToName(UserRole role) {
  switch (role) {
    case UserRole.user:
      return 'user';
    case UserRole.driver:
      return 'driver';
    case UserRole.serviceStaff:
      return 'service_staff';
  }
}

UserRole userRoleFromName(String? name) {
  switch (name) {
    case 'driver':
      return UserRole.driver;
    case 'service_staff':
      return UserRole.serviceStaff;
    default:
      return UserRole.user;
  }
}
