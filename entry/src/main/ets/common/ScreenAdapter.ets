import { display } from '@kit.ArkUI';

export type DeviceKind = 'phone' | 'foldable' | 'tablet';

export class ScreenInfo {
  screenWidth: number = 0;
  screenHeight: number = 0;
  safeAreaTop: number = 0;
  safeAreaBottom: number = 0;
  isLandscape: boolean = false;
  deviceType: DeviceKind = 'phone';
  scaleFactor: number = 1;
  gameWidth: number = 400;
  gameHeight: number = 850;
  canvasWidth: number = 400;
  canvasHeight: number = 850;
  joystickBaseSize: number = 0;
  joystickKnobSize: number = 0;
  joystickMaxOffset: number = 0;
  skillBtnSize: number = 0;
  controlBarHeight: number = 0;
  controlPaddingH: number = 0;
  maxEnemyCount: number = 5;
  enemySpawnRate: number = 0.02;
}

let adapterInstance: ScreenAdapter | null = null;

export class ScreenAdapter {
  private info: ScreenInfo = new ScreenInfo();

  static getInstance(): ScreenAdapter {
    if (adapterInstance === null) {
      adapterInstance = new ScreenAdapter();
    }
    return adapterInstance as ScreenAdapter;
  }

  getScreenInfo(): ScreenInfo {
    return this.info;
  }

  recalculate(): void {
    const disp: display.Display = display.getDefaultDisplaySync();
    this.info.screenWidth = px2vp(disp.width);
    this.info.screenHeight = px2vp(disp.height);
    this.info.isLandscape = this.info.screenWidth > this.info.screenHeight;

    this.detectSafeArea();
    this.detectDeviceType();
    this.calcGameCanvas();
    this.calcControls();
    this.calcDifficulty();
  }

  private detectSafeArea(): void {
    this.info.safeAreaTop = 48;
    this.info.safeAreaBottom = 34;
  }

  private detectDeviceType(): void {
    const w: number = this.info.screenWidth;
    if (w >= 840) {
      this.info.deviceType = 'tablet';
    } else if (w >= 600) {
      this.info.deviceType = 'foldable';
    } else {
      this.info.deviceType = 'phone';
    }
  }

  private calcGameCanvas(): void {
    const dt: DeviceKind = this.info.deviceType;
    const ls: boolean = this.info.isLandscape;

    if (dt === 'tablet' && ls) {
      this.info.gameWidth = 500;
      this.info.gameHeight = 700;
    } else if (dt === 'foldable') {
      this.info.gameWidth = 450;
      this.info.gameHeight = 800;
    } else {
      this.info.gameWidth = 400;
      this.info.gameHeight = 850;
    }

    const usableHeight: number = this.info.screenHeight - this.info.safeAreaTop - this.info.safeAreaBottom;
    this.info.scaleFactor = Math.min(
      this.info.screenWidth / this.info.gameWidth,
      usableHeight / this.info.gameHeight
    );
    this.info.canvasWidth = this.info.gameWidth * this.info.scaleFactor;
    this.info.canvasHeight = this.info.gameHeight * this.info.scaleFactor;
  }

  private calcControls(): void {
    const w: number = this.info.screenWidth;
    const dt: DeviceKind = this.info.deviceType;
    const ls: boolean = this.info.isLandscape;

    if (dt === 'tablet' && ls) {
      this.info.joystickBaseSize = w * 0.14;
      this.info.skillBtnSize = w * 0.06;
      this.info.controlPaddingH = w * 0.03;
    } else if (dt === 'foldable') {
      this.info.joystickBaseSize = w * 0.20;
      this.info.skillBtnSize = w * 0.10;
      this.info.controlPaddingH = w * 0.04;
    } else {
      this.info.joystickBaseSize = w * 0.22;
      this.info.skillBtnSize = Math.min(w * 0.13, this.info.joystickBaseSize * 0.48);
      this.info.controlPaddingH = w * 0.04;
    }

    this.info.joystickKnobSize = this.info.joystickBaseSize * 0.42;
    this.info.joystickMaxOffset = this.info.joystickBaseSize * 0.32;
    this.info.controlBarHeight = this.info.joystickBaseSize + this.info.safeAreaBottom + 20;
  }

  private calcDifficulty(): void {
    if (this.info.deviceType === 'tablet') {
      this.info.maxEnemyCount = 8;
      this.info.enemySpawnRate = 0.03;
    } else if (this.info.deviceType === 'foldable') {
      this.info.maxEnemyCount = 6;
      this.info.enemySpawnRate = 0.025;
    } else {
      this.info.maxEnemyCount = 5;
      this.info.enemySpawnRate = 0.02;
    }
  }

  normalizeTouchX(rawX: number, componentWidth: number): number {
    return (rawX / componentWidth) * this.info.joystickBaseSize;
  }

  normalizeTouchY(rawY: number, componentHeight: number): number {
    return (rawY / componentHeight) * this.info.joystickBaseSize;
  }

  scale(baseValue: number): number {
    return baseValue * this.info.scaleFactor;
  }

  canvasX(): number {
    return (this.info.screenWidth - this.info.canvasWidth) / 2;
  }

  canvasY(): number {
    return this.info.safeAreaTop;
  }
}
