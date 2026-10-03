import qrcode from './vendor/qrcode.mjs';
import { isEncryptedLink } from './clients.mjs';

export function renderEncryptedQr(canvas, encrypted) {
  if (!isEncryptedLink(encrypted)) {
    throw new Error('QR codes require an encrypted subscription link.');
  }
  const code = qrcode(0, 'M');
  code.addData(encrypted, 'Byte');
  code.make();
  const modules = code.getModuleCount();
  const border = 4;
  const scale = 4;
  canvas.width = canvas.height = (modules + border * 2) * scale;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('Canvas is unavailable.');
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.fillStyle = '#000000';
  for (let row = 0; row < modules; row += 1) {
    for (let column = 0; column < modules; column += 1) {
      if (code.isDark(row, column)) {
        context.fillRect((column + border) * scale, (row + border) * scale, scale, scale);
      }
    }
  }
}
