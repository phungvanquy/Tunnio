export class Canvas {
  rectangles = [];
  height = 0;
  get width() { return this.size ?? 0; }
  set width(value) {
    this.size = value;
    this.rectangles = [];
  }
  getContext() {
    const rectangles = this.rectangles;
    return {
      fillStyle: '',
      fillRect(x, y, width, height) {
        rectangles.push({ x, y, width, height, color: this.fillStyle });
      },
    };
  }
}
