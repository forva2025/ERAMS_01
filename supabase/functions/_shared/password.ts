const CHARS =
  'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';

/// Generates a random temporary password the admin shares with the user.
/// The user is forced to set their own password on first login.
export function generateTempPassword(): string {
  const bytes = new Uint8Array(14);
  crypto.getRandomValues(bytes);
  let pwd = '';
  for (let i = 0; i < bytes.length; i++) pwd += CHARS[bytes[i] % CHARS.length];
  return pwd;
}
