import { display } from '@kit.ArkUI';
import { saveGameState, getSavedGameState, clearSavedGameState, GameState } from '../entryability/EntryAbility';
import { ScreenAdapter, ScreenInfo, DeviceKind } from '../common/ScreenAdapter';

interface Positionable {
  x: number;
  y: number;
  width: number;
  height: number;
}

class Entity implements Positionable {
  x: number = 0;
  y: number = 0;
  width: number = 40;
  height: number = 40;
}

class Bullet extends Entity {
  speed: number = 8;
  constructor(x: number, y: number) {
    super();
    this.width = 6;
    this.height = 12;
    this.x = x;
    this.y = y;
  }
}

class Enemy extends Entity {
  speed: number = 3;
  type: 'small' | 'medium' | 'large' = 'small';
  hp: number = 1;
  constructor(x: number, y: number, type: 'small' | 'medium' | 'large' = 'small') {
    super();
    this.type = type;
    if (type === 'small') {
      this.width = 40;
      this.height = 40;
      this.speed = 3;
      this.hp = 1;
    } else if (type === 'medium') {
      this.width = 55;
      this.height = 55;
      this.speed = 2;
      this.hp = 2;
    } else {
      this.width = 70;
      this.height = 70;
      this.speed = 1.5;
      this.hp = 3;
    }
    this.x = x;
    this.y = y;
  }
}

class ParticleEffect {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  color: string;
  size: number;

  constructor(x: number, y: number, color: string) {
    this.x = x;
    this.y = y;
    this.vx = (Math.random() - 0.5) * 8;
    this.vy = (Math.random() - 0.5) * 8;
    this.life = 30;
    this.color = color;
    this.size = Math.random() * 6 + 2;
  }
}

class PowerUp extends Entity {
  type: 'health' | 'double' | 'speed';
  speed: number = 2;
  constructor(x: number, y: number, type: 'health' | 'double' | 'speed') {
    super();
    this.type = type;
    this.width = 25;
    this.height = 25;
    this.x = x;
    this.y = y;
  }
}

@Entry
@Component
struct GamePage {
  @State playerX: number = 180;
  @State playerY: number = 600;
  @State playerWidth: number = 50;
  @State playerHeight: number = 50;
  @State playerHp: number = 5;
  @State score: number = 0;
  @State gameOver: boolean = false;
  @State gameStarted: boolean = false;
  @State paused: boolean = false;

  @State bullets: Bullet[] = [];
  @State enemies: Enemy[] = [];
  @State particles: ParticleEffect[] = [];
  @State powerUps: PowerUp[] = [];

  private shootCooldown: number = 0;
  private intervalId: number = -1;
  private doubleShot: boolean = false;
  private doubleShotTimer: number = 0;
  private multiShotStage: number = 0;
  private multiShotTimer: number = 0;
  private isMultiShooting: boolean = false;
  private clearScreenCooldown: number = 0;
  private playerSpeedBoost: boolean = false;
  private playerSpeedBoostTimer: number = 0;

  private leftPressed: boolean = false;
  private rightPressed: boolean = false;
  private upPressed: boolean = false;
  private downPressed: boolean = false;

  private stars: number[][] = [];
  private bgOffset: number = 0;

  private adapter: ScreenAdapter | null = null;
  @State si: ScreenInfo = new ScreenInfo();

  @State deviceType: DeviceKind = 'phone';
  private isLandscape: boolean = false;
  @State migrationStatus: 'none' | 'saving' | 'restoring' = 'none';
  @State showMigrationBanner: boolean = false;
  private joystickActive: boolean = false;
  private joystickTouchId: number = -1;

  @State joystickKnobOffsetX: number = 0;
  @State joystickKnobOffsetY: number = 0;
  private fireLongPressTimer: number = -1;
  private isFireLongPress: boolean = false;
  private displayChangeCallback: (() => void) | null = null;

  aboutToAppear() {
    this.applyScreenInfo();
    this.initStars();
    this.startGameLoop();
    this.restoreGameState();
    this.listenDisplayChange();
  }

  aboutToDisappear() {
    if (this.intervalId !== -1) {
      clearInterval(this.intervalId);
    }
    if (this.displayChangeCallback !== null) {
      display.off('change', this.displayChangeCallback);
    }
  }

  applyScreenInfo() {
    if (this.adapter === null) {
      this.adapter = ScreenAdapter.getInstance();
    }
    this.adapter.recalculate();
    const s: ScreenInfo = this.adapter.getScreenInfo();
    this.si = s;
    this.isLandscape = s.isLandscape;
    this.deviceType = s.deviceType;
    this.playerWidth = 50 * s.scaleFactor;
    this.playerHeight = 50 * s.scaleFactor;
  }

  listenDisplayChange() {
    try {
      this.displayChangeCallback = () => {
        const oldLandscape: boolean = this.isLandscape;
        this.applyScreenInfo();
        if (oldLandscape !== this.isLandscape) {
          this.initStars();
          if (this.gameStarted && !this.gameOver) {
            this.playerX = this.si.gameWidth * this.si.scaleFactor / 2 - this.playerWidth / 2;
            this.playerY = this.si.gameHeight * this.si.scaleFactor * 0.7;
          }
        }
      };
      display.on('change', this.displayChangeCallback);
    } catch (e) {
      console.info('display change not supported: ' + e);
    }
  }

  initStars() {
    this.stars = [];
    for (let i = 0; i < 100; i++) {
      this.stars.push([
        Math.random() * this.si.gameWidth * this.si.scaleFactor,
        Math.random() * this.si.gameHeight * this.si.scaleFactor,
        Math.random() * 2 + 0.5
      ]);
    }
  }

  startGameLoop() {
    const callback: () => void = () => {
      if (!this.gameStarted || this.paused) return;
      if (this.gameOver) return;
      this.updateGame();
    };
    this.intervalId = setInterval(callback, 16);
  }

  updateGame() {
    const sf: number = this.si.scaleFactor;
    const step: number = (this.playerSpeedBoost ? 12 : 8) * sf;
    const maxX: number = this.si.gameWidth * sf - this.playerWidth - 10;
    const maxY: number = this.si.gameHeight * sf - this.playerHeight - 10;
    if (this.leftPressed && this.playerX > 10) {
      this.playerX -= step;
    }
    if (this.rightPressed && this.playerX < maxX) {
      this.playerX += step;
    }
    if (this.upPressed && this.playerY > 50) {
      this.playerY -= step;
    }
    if (this.downPressed && this.playerY < maxY) {
      this.playerY += step;
    }

    if (this.shootCooldown > 0) {
      this.shootCooldown--;
    }
    if (this.doubleShotTimer > 0) {
      this.doubleShotTimer--;
      if (this.doubleShotTimer === 0) {
        this.doubleShot = false;
      }
    }
    if (this.multiShotTimer > 0) {
      this.multiShotTimer--;
      if (this.multiShotTimer === 0) {
        this.isMultiShooting = true;
        this.multiShotStage = 0;
      }
    }
    if (this.clearScreenCooldown > 0) {
      this.clearScreenCooldown--;
    }
    if (this.playerSpeedBoostTimer > 0) {
      this.playerSpeedBoostTimer--;
      if (this.playerSpeedBoostTimer === 0) {
        this.playerSpeedBoost = false;
      }
    }

    for (let i: number = 0; i < this.bullets.length; i++) {
      const bullet: Bullet = this.bullets[i];
      bullet.y -= bullet.speed * sf;
      if (bullet.y + bullet.height < 0) {
        this.bullets.splice(i, 1);
        i--;
      }
    }

    for (let i: number = 0; i < this.enemies.length; i++) {
      const enemy: Enemy = this.enemies[i];
      enemy.y += enemy.speed * sf;
      if (enemy.y > this.si.gameHeight * sf) {
        this.enemies.splice(i, 1);
        i--;
      }
    }

    for (let i: number = 0; i < this.particles.length; i++) {
      const p: ParticleEffect = this.particles[i];
      p.x += p.vx * sf;
      p.y += p.vy * sf;
      p.life--;
      p.size *= 0.95;
      if (p.life <= 0) {
        this.particles.splice(i, 1);
        i--;
      }
    }

    for (let i: number = 0; i < this.powerUps.length; i++) {
      const pu: PowerUp = this.powerUps[i];
      pu.y += pu.speed * sf;
      if (pu.y > this.si.gameHeight * sf) {
        this.powerUps.splice(i, 1);
        i--;
      }
    }

    for (let i: number = 0; i < this.bullets.length; i++) {
      const bullet: Bullet = this.bullets[i];
      for (let j: number = 0; j < this.enemies.length; j++) {
        const enemy: Enemy = this.enemies[j];
        if (this.checkCollision(bullet, enemy)) {
          this.bullets.splice(i, 1);
          i--;
          enemy.hp--;
          if (enemy.hp <= 0) {
            this.createExplosion(enemy.x + enemy.width / 2, enemy.y + enemy.height / 2, enemy.type);
            this.enemies.splice(j, 1);
            this.score += enemy.type === 'small' ? 10 : enemy.type === 'medium' ? 25 : 50;
            if (Math.random() < 0.15) {
              const types: ('health' | 'double' | 'speed')[] = ['health', 'double', 'speed'];
              this.powerUps.push(new PowerUp(enemy.x, enemy.y, types[Math.floor(Math.random() * 3)]));
            }
          } else {
            this.createExplosion(bullet.x, bullet.y, 'small');
          }
          break;
        }
      }
    }

    for (let i: number = 0; i < this.enemies.length; i++) {
      const enemy: Enemy = this.enemies[i];
      if (this.checkPlayerCollision(enemy)) {
        this.playerHp--;
        this.createExplosion(enemy.x + enemy.width / 2, enemy.y + enemy.height / 2, enemy.type);
        this.enemies.splice(i, 1);
        i--;
        if (this.playerHp <= 0) {
          this.gameOver = true;
          break;
        }
      }
    }

    for (let i: number = 0; i < this.powerUps.length; i++) {
      const pu: PowerUp = this.powerUps[i];
      if (this.checkPlayerCollision(pu)) {
        if (pu.type === 'health' && this.playerHp < 5) {
          this.playerHp++;
        } else if (pu.type === 'double') {
          this.doubleShot = true;
          this.doubleShotTimer = 300;
        } else if (pu.type === 'speed') {
          this.playerSpeedBoost = true;
          this.playerSpeedBoostTimer = 300;
        }
        this.powerUps.splice(i, 1);
        i--;
      }
    }

    const difficulty: number = Math.min(0.05, this.si.enemySpawnRate + this.score * 0.0001);
    if (Math.random() < difficulty && this.enemies.length < this.si.maxEnemyCount) {
      const randX: number = Math.random() * (this.si.gameWidth * sf - 60 * sf);
      const rand: number = Math.random();
      let type: 'small' | 'medium' | 'large' = 'small';
      if (rand > 0.7) type = 'medium';
      if (rand > 0.9) type = 'large';
      this.enemies.push(new Enemy(randX, -60 * sf, type));
    }

    this.bgOffset = (this.bgOffset + 1 * sf) % (this.si.gameHeight * sf);
  }

  checkCollision(a: Entity, b: Entity): boolean {
    const sf: number = this.si.scaleFactor;
    const aRight: number = a.x + a.width * sf;
    const bRight: number = b.x + b.width * sf;
    const aBottom: number = a.y + a.height * sf;
    const bBottom: number = b.y + b.height * sf;
    return !(aRight < b.x || bRight < a.x || aBottom < b.y || bBottom < a.y);
  }

  checkPlayerCollision(entity: Entity): boolean {
    const sf: number = this.si.scaleFactor;
    const playerRight: number = this.playerX + this.playerWidth;
    const entityRight: number = entity.x + entity.width * sf;
    const playerBottom: number = this.playerY + this.playerHeight;
    const entityBottom: number = entity.y + entity.height * sf;
    return !(playerRight < entity.x || entityRight < this.playerX ||
      playerBottom < entity.y || entityBottom < this.playerY);
  }

  createExplosion(x: number, y: number, type: 'small' | 'medium' | 'large') {
    const count: number = type === 'large' ? 20 : type === 'medium' ? 15 : 10;
    const color: string = type === 'large' ? '#ff6b35' : type === 'medium' ? '#f7931e' : '#ffcc00';
    for (let i = 0; i < count; i++) {
      this.particles.push(new ParticleEffect(x, y, color));
    }
  }

  fire() {
    if (this.gameOver || this.paused) return;
    if (this.shootCooldown <= 0) {
      if (this.isMultiShooting) {
        switch (this.multiShotStage) {
          case 0:
            this.bullets.push(new Bullet(this.playerX + this.playerWidth / 2 - 3, this.playerY - 10));
            break;
          case 1:
            this.bullets.push(new Bullet(this.playerX + 5, this.playerY - 10));
            this.bullets.push(new Bullet(this.playerX + this.playerWidth - 11, this.playerY - 10));
            break;
          case 2:
            this.bullets.push(new Bullet(this.playerX + 5, this.playerY - 10));
            this.bullets.push(new Bullet(this.playerX + this.playerWidth / 2 - 3, this.playerY - 10));
            this.bullets.push(new Bullet(this.playerX + this.playerWidth - 11, this.playerY - 10));
            break;
          case 3:
            this.bullets.push(new Bullet(this.playerX + 5, this.playerY - 10));
            this.bullets.push(new Bullet(this.playerX + this.playerWidth - 11, this.playerY - 10));
            break;
          case 4:
            this.bullets.push(new Bullet(this.playerX + this.playerWidth / 2 - 3, this.playerY - 10));
            this.multiShotStage = -1;
            this.isMultiShooting = false;
            break;
        }
        this.multiShotStage++;
      } else if (this.doubleShot) {
        this.bullets.push(new Bullet(this.playerX + 5, this.playerY - 10));
        this.bullets.push(new Bullet(this.playerX + this.playerWidth - 11, this.playerY - 10));
      } else {
        this.bullets.push(new Bullet(this.playerX + this.playerWidth / 2 - 3, this.playerY - 10));
      }
      this.shootCooldown = 10;
    }
  }

  clearScreen() {
    if (this.clearScreenCooldown > 0 || this.gameOver || this.paused) return;
    for (let i = 0; i < this.enemies.length; i++) {
      const enemy: Enemy = this.enemies[i];
      this.createExplosion(enemy.x + enemy.width / 2, enemy.y + enemy.height / 2, enemy.type);
      this.score += enemy.type === 'small' ? 10 : enemy.type === 'medium' ? 25 : 50;
    }
    this.enemies = [];
    this.clearScreenCooldown = 600;
  }

  handleJoystickTouch(event: TouchEvent) {
    if (this.gameOver || this.paused) return;
    const baseSize: number = this.si.joystickBaseSize;
    const maxOffset: number = this.si.joystickMaxOffset;

    if (event.type === TouchType.Down) {
      this.joystickActive = true;
      this.joystickTouchId = event.touches[0].id;
    }
    if ((event.type === TouchType.Move || event.type === TouchType.Down) && this.joystickActive) {
      const rawX: number = event.touches[0].x;
      const rawY: number = event.touches[0].y;
      const normX: number = this.adapter !== null ? this.adapter.normalizeTouchX(rawX, baseSize) : rawX;
      const normY: number = this.adapter !== null ? this.adapter.normalizeTouchY(rawY, baseSize) : rawY;
      const centerX: number = baseSize / 2;
      const centerY: number = baseSize / 2;
      const dx: number = normX - centerX;
      const dy: number = normY - centerY;
      const dist: number = Math.sqrt(dx * dx + dy * dy);
      const clampedDist: number = Math.min(dist, maxOffset);
      const angle: number = Math.atan2(dy, dx);
      this.joystickKnobOffsetX = clampedDist * Math.cos(angle);
      this.joystickKnobOffsetY = clampedDist * Math.sin(angle);
      const threshold: number = maxOffset * 0.3;
      this.leftPressed = this.joystickKnobOffsetX < -threshold;
      this.rightPressed = this.joystickKnobOffsetX > threshold;
      this.upPressed = this.joystickKnobOffsetY < -threshold;
      this.downPressed = this.joystickKnobOffsetY > threshold;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.joystickActive = false;
      this.joystickKnobOffsetX = 0;
      this.joystickKnobOffsetY = 0;
      this.leftPressed = false;
      this.rightPressed = false;
      this.upPressed = false;
      this.downPressed = false;
    }
  }

  handleFireTouch(event: TouchEvent) {
    if (this.gameOver || this.paused) return;
    if (event.type === TouchType.Down) {
      this.fire();
      this.isFireLongPress = false;
      this.fireLongPressTimer = setTimeout(() => {
        this.isFireLongPress = true;
        this.autoFire();
      }, 300);
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (this.fireLongPressTimer !== -1) {
        clearTimeout(this.fireLongPressTimer);
        this.fireLongPressTimer = -1;
      }
      this.isFireLongPress = false;
    }
  }

  autoFire(): void {
    if (!this.isFireLongPress || this.gameOver || this.paused) return;
    this.fire();
    setTimeout(() => this.autoFire(), 150);
  }

  restartGame() {
    const sf: number = this.si.scaleFactor;
    this.playerHp = 5;
    this.score = 0;
    this.bullets = [];
    this.enemies = [];
    this.particles = [];
    this.powerUps = [];
    this.playerX = 180 * sf;
    this.playerY = 600 * sf;
    this.gameOver = false;
    this.shootCooldown = 0;
    this.doubleShot = false;
    this.doubleShotTimer = 0;
    this.multiShotStage = 0;
    this.multiShotTimer = 0;
    this.isMultiShooting = false;
    this.clearScreenCooldown = 0;
    this.playerSpeedBoost = false;
    this.playerSpeedBoostTimer = 0;
    this.leftPressed = false;
    this.rightPressed = false;
    this.upPressed = false;
    this.downPressed = false;
    this.joystickActive = false;
    this.joystickKnobOffsetX = 0;
    this.joystickKnobOffsetY = 0;
  }

  startGame() {
    this.gameStarted = true;
    this.restartGame();
  }

  saveCurrentGameState() {
    this.migrationStatus = 'saving';
    const state: GameState = {
      playerX: this.playerX,
      playerY: this.playerY,
      playerHp: this.playerHp,
      score: this.score,
      gameOver: this.gameOver,
      gameStarted: this.gameStarted,
      doubleShot: this.doubleShot,
      doubleShotTimer: this.doubleShotTimer,
      clearScreenCooldown: this.clearScreenCooldown,
    };
    saveGameState(state);
    this.showMigrationBanner = true;
    setTimeout(() => {
      this.showMigrationBanner = false;
      this.migrationStatus = 'none';
    }, 3000);
  }

  restoreGameState() {
    const state: GameState | null = getSavedGameState();
    if (state !== null) {
      this.migrationStatus = 'restoring';
      this.playerX = state.playerX;
      this.playerY = state.playerY;
      this.playerHp = state.playerHp;
      this.score = state.score;
      this.gameOver = state.gameOver;
      this.gameStarted = state.gameStarted;
      this.doubleShot = state.doubleShot;
      this.doubleShotTimer = state.doubleShotTimer;
      this.clearScreenCooldown = state.clearScreenCooldown;
      this.bullets = [];
      this.enemies = [];
      this.particles = [];
      this.powerUps = [];
      this.showMigrationBanner = true;
      clearSavedGameState();
      setTimeout(() => {
        this.showMigrationBanner = false;
        this.migrationStatus = 'none';
      }, 3000);
    }
  }

  @Builder
  gameCanvas() {
    Stack() {
      Rect()
        .width('100%')
        .height('100%')
        .fill('#0a0a1a')

      ForEach(this.stars, (star: number[]) => {
        Circle()
          .width(star[2])
          .height(star[2])
          .fill('#ffffff')
          .opacity(Math.random() * 0.5 + 0.3)
          .position({
            x: star[0],
            y: (star[1] + this.bgOffset * star[2]) % (this.si.gameHeight * this.si.scaleFactor)
          })
      })

      if (!this.gameOver) {
        Column() {
          Path()
            .width(this.playerWidth)
            .height(this.playerHeight)
            .commands(`
              M ${this.playerWidth / 2} 0
              L ${this.playerWidth} ${this.playerHeight}
              L ${this.playerWidth / 2} ${this.playerHeight * 0.7}
              L 0 ${this.playerHeight}
              Z
            `)
            .fill('#00e5ff')
            .stroke('#00b8d4')
            .strokeWidth(2 * this.si.scaleFactor)
        }
        .position({ x: this.playerX, y: this.playerY })
      }

      ForEach(this.bullets, (bullet: Bullet) => {
        Column() {
          Path()
            .width(bullet.width * this.si.scaleFactor)
            .height(bullet.height * this.si.scaleFactor)
            .commands('M 3 0 L 6 8 L 3 12 L 0 8 Z')
            .fill('#ffeb3b')
            .shadow({ radius: 8 * this.si.scaleFactor, color: '#ffeb3b', offsetX: 0, offsetY: 0 })
        }
        .position({ x: bullet.x, y: bullet.y })
      }, (bullet: Bullet) => `bullet_${bullet.x}_${bullet.y}`)

      ForEach(this.enemies, (enemy: Enemy) => {
        Column() {
          if (enemy.type === 'small') {
            Path()
              .width(enemy.width * this.si.scaleFactor)
              .height(enemy.height * this.si.scaleFactor)
              .commands(`
                M ${enemy.width / 2} ${enemy.height}
                L ${enemy.width} 0
                L ${enemy.width / 2} ${enemy.height * 0.3}
                L 0 0
                Z
              `)
              .fill('#ff5252')
              .stroke('#d32f2f')
              .strokeWidth(2 * this.si.scaleFactor)
          } else if (enemy.type === 'medium') {
            Path()
              .width(enemy.width * this.si.scaleFactor)
              .height(enemy.height * this.si.scaleFactor)
              .commands(`
                M ${enemy.width / 2} ${enemy.height}
                L ${enemy.width} ${enemy.height * 0.2}
                L ${enemy.width * 0.8} 0
                L ${enemy.width * 0.2} 0
                L 0 ${enemy.height * 0.2}
                Z
              `)
              .fill('#ff9800')
              .stroke('#f57c00')
              .strokeWidth(2 * this.si.scaleFactor)
          } else {
            Path()
              .width(enemy.width * this.si.scaleFactor)
              .height(enemy.height * this.si.scaleFactor)
              .commands(`
                M ${enemy.width / 2} ${enemy.height}
                L ${enemy.width} ${enemy.height * 0.3}
                L ${enemy.width * 0.9} ${enemy.height * 0.1}
                L ${enemy.width * 0.7} 0
                L ${enemy.width * 0.3} 0
                L ${enemy.width * 0.1} ${enemy.height * 0.1}
                L 0 ${enemy.height * 0.3}
                Z
              `)
              .fill('#9c27b0')
              .stroke('#7b1fa2')
              .strokeWidth(2 * this.si.scaleFactor)
          }
        }
        .position({ x: enemy.x, y: enemy.y })
      }, (enemy: Enemy) => `enemy_${enemy.x}_${enemy.y}`)

      ForEach(this.particles, (p: ParticleEffect) => {
        Circle()
          .width(p.size * this.si.scaleFactor)
          .height(p.size * this.si.scaleFactor)
          .fill(p.color)
          .position({ x: p.x, y: p.y })
          .opacity(p.life / 30)
      })

      ForEach(this.powerUps, (pu: PowerUp) => {
        Stack() {
          Circle()
            .width(pu.width * this.si.scaleFactor)
            .height(pu.height * this.si.scaleFactor)
            .fill(pu.type === 'health' ? '#4caf50' : pu.type === 'double' ? '#2196f3' : '#ff9800')
            .shadow({ radius: 10 * this.si.scaleFactor, color: pu.type === 'health' ? '#4caf50' : pu.type === 'double' ? '#2196f3' : '#ff9800', offsetX: 0, offsetY: 0 })
          Text(pu.type === 'health' ? '❤️' : pu.type === 'double' ? '⚡' : '🚀')
            .fontSize(16 * this.si.scaleFactor)
        }
        .position({ x: pu.x, y: pu.y })
      })

      Row() {
        Text(`❤️ ${this.playerHp}`)
          .fontSize(28 * this.si.scaleFactor)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .textShadow({ radius: 4 * this.si.scaleFactor, color: '#ff0000', offsetX: 0, offsetY: 0 })
          .margin(10 * this.si.scaleFactor)
        Text(`🎯 ${this.score}`)
          .fontSize(28 * this.si.scaleFactor)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .textShadow({ radius: 4 * this.si.scaleFactor, color: '#ffeb3b', offsetX: 0, offsetY: 0 })
          .margin(10 * this.si.scaleFactor)
        if (this.doubleShot) {
          Text('⚡')
            .fontSize(28 * this.si.scaleFactor)
            .textShadow({ radius: 4 * this.si.scaleFactor, color: '#2196f3', offsetX: 0, offsetY: 0 })
        }
        if (this.playerSpeedBoost) {
          Text('🚀')
            .fontSize(28 * this.si.scaleFactor)
            .textShadow({ radius: 4 * this.si.scaleFactor, color: '#ff9800', offsetX: 0, offsetY: 0 })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ left: 15 * this.si.scaleFactor, right: 15 * this.si.scaleFactor, top: this.si.safeAreaTop + 5 })
      .position({ x: 0, y: 0 })

      if (!this.gameStarted) {
        Column() {
          Text('🚀 星际战机')
            .fontSize(48 * this.si.scaleFactor)
            .fontColor('#00e5ff')
            .fontWeight(FontWeight.Bold)
            .textShadow({ radius: 10 * this.si.scaleFactor, color: '#00e5ff', offsetX: 0, offsetY: 0 })
            .margin(30 * this.si.scaleFactor)
          Text('消灭敌机，躲避碰撞')
            .fontSize(20 * this.si.scaleFactor)
            .fontColor('#ffffff')
            .opacity(0.8)
            .margin(10 * this.si.scaleFactor)
          Text('收集道具获得能力')
            .fontSize(20 * this.si.scaleFactor)
            .fontColor('#ffffff')
            .opacity(0.8)
            .margin(10 * this.si.scaleFactor)
          Button('开始游戏')
            .fontSize(24 * this.si.scaleFactor)
            .width(200 * this.si.scaleFactor)
            .height(60 * this.si.scaleFactor)
            .margin(30 * this.si.scaleFactor)
            .backgroundColor('#00e5ff')
            .onClick(() => {
              this.startGame();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.8)')
      }

      if (this.gameOver) {
        Column() {
          Text('GAME OVER')
            .fontSize(42 * this.si.scaleFactor)
            .fontColor('#ff5252')
            .fontWeight(FontWeight.Bold)
            .textShadow({ radius: 10 * this.si.scaleFactor, color: '#ff5252', offsetX: 0, offsetY: 0 })
            .margin(20 * this.si.scaleFactor)
          Text(`最终得分: ${this.score}`)
            .fontSize(28 * this.si.scaleFactor)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .margin(20 * this.si.scaleFactor)
          Button('重新开始')
            .fontSize(24 * this.si.scaleFactor)
            .width(200 * this.si.scaleFactor)
            .height(60 * this.si.scaleFactor)
            .margin(30 * this.si.scaleFactor)
            .backgroundColor('#ff5252')
            .onClick(() => {
              this.restartGame();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.85)')
      }

      if (this.paused && this.gameStarted && !this.gameOver) {
        Column() {
          Text('⏸️ 暂停')
            .fontSize(48 * this.si.scaleFactor)
            .fontColor('#ffffff')
            .fontWeight(FontWeight.Bold)
            .textShadow({ radius: 10 * this.si.scaleFactor, color: '#ffffff', offsetX: 0, offsetY: 0 })
            .margin(30 * this.si.scaleFactor)
          Button('继续游戏')
            .fontSize(24 * this.si.scaleFactor)
            .width(200 * this.si.scaleFactor)
            .height(60 * this.si.scaleFactor)
            .margin(30 * this.si.scaleFactor)
            .backgroundColor('#4caf50')
            .onClick(() => {
              this.paused = false;
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.7)')
      }

      if (this.showMigrationBanner) {
        Row() {
          if (this.migrationStatus === 'saving') {
            Text('🔄 游戏状态已保存，可流转到其他设备')
              .fontSize(18 * this.si.scaleFactor)
              .fontColor('#ffffff')
          } else if (this.migrationStatus === 'restoring') {
            Text('✅ 游戏已从其他设备恢复，继续战斗！')
              .fontSize(18 * this.si.scaleFactor)
              .fontColor('#ffffff')
          }
        }
        .width('100%')
        .height(50 * this.si.scaleFactor)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.migrationStatus === 'saving' ? '#1565c0' : '#2e7d32')
        .position({ x: 0, y: this.si.safeAreaTop + 10 })
      }
    }
  }

  @Builder
  controlPanel() {
    Row() {
      Stack() {
        Circle()
          .width(this.si.joystickBaseSize)
          .height(this.si.joystickBaseSize)
          .fill('rgba(255,255,255,0.06)')
          .stroke('rgba(255,255,255,0.25)')
          .strokeWidth(1.5)
        Circle()
          .width(this.si.joystickKnobSize)
          .height(this.si.joystickKnobSize)
          .fill('rgba(255,255,255,0.3)')
          .offset({
            x: this.si.joystickBaseSize / 2 - this.si.joystickKnobSize / 2 + this.joystickKnobOffsetX,
            y: this.si.joystickBaseSize / 2 - this.si.joystickKnobSize / 2 + this.joystickKnobOffsetY
          })
      }
      .width(this.si.joystickBaseSize)
      .height(this.si.joystickBaseSize)
      .onTouch((event: TouchEvent) => {
        this.handleJoystickTouch(event);
      })

      Blank().layoutWeight(1)

      Column() {
        Row() {
          Stack() {
            Circle()
              .width(this.si.skillBtnSize)
              .height(this.si.skillBtnSize)
              .fill('rgba(255,82,82,0.6)')
              .stroke('rgba(255,82,82,0.8)')
              .strokeWidth(1.5)
            Text('🔫')
              .fontSize(this.si.skillBtnSize * 0.4)
              .fontColor('#ffffff')
          }
          .width(this.si.skillBtnSize)
          .height(this.si.skillBtnSize)
          .onTouch((event: TouchEvent) => {
            this.handleFireTouch(event);
          })

          Stack() {
            Circle()
              .width(this.si.skillBtnSize)
              .height(this.si.skillBtnSize)
              .fill('rgba(156,39,176,0.6)')
              .stroke('rgba(156,39,176,0.8)')
              .strokeWidth(1.5)
            Text('💥')
              .fontSize(this.si.skillBtnSize * 0.4)
              .fontColor('#ffffff')
          }
          .width(this.si.skillBtnSize)
          .height(this.si.skillBtnSize)
          .onClick(() => {
            if (!this.isMultiShooting) {
              this.multiShotTimer = 60;
            }
          })
        }
        .margin({ bottom: this.si.skillBtnSize * 0.15 })

        Row() {
          Stack() {
            Circle()
              .width(this.si.skillBtnSize)
              .height(this.si.skillBtnSize)
              .fill('rgba(255,235,59,0.6)')
              .stroke('rgba(255,235,59,0.8)')
              .strokeWidth(1.5)
            Text('⚡')
              .fontSize(this.si.skillBtnSize * 0.4)
              .fontColor('#ffffff')
          }
          .width(this.si.skillBtnSize)
          .height(this.si.skillBtnSize)
          .onClick(() => {
            this.clearScreen();
          })

          Stack() {
            Circle()
              .width(this.si.skillBtnSize)
              .height(this.si.skillBtnSize)
              .fill('rgba(21,101,192,0.6)')
              .stroke('rgba(21,101,192,0.8)')
              .strokeWidth(1.5)
            Text('🔄')
              .fontSize(this.si.skillBtnSize * 0.4)
              .fontColor('#ffffff')
          }
          .width(this.si.skillBtnSize)
          .height(this.si.skillBtnSize)
          .onClick(() => {
            this.saveCurrentGameState();
          })
        }
      }
    }
    .width('100%')
    .height(this.si.controlBarHeight)
    .padding({
      left: this.si.controlPaddingH,
      right: this.si.controlPaddingH,
      bottom: this.si.safeAreaBottom + 6
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  infoPanel() {
    Column() {
      Text('🎮 游戏信息')
        .fontSize(32 * this.si.scaleFactor)
        .fontColor('#00e5ff')
        .fontWeight(FontWeight.Bold)
        .margin(20 * this.si.scaleFactor)

      Column() {
        Row() {
          Text('❤️ 生命值')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor('#ffffff')
            .opacity(0.8)
          Text(`${this.playerHp}`)
            .fontSize(22 * this.si.scaleFactor)
            .fontColor('#ff5252')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding(15 * this.si.scaleFactor)

        Row() {
          Text('🎯 得分')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor('#ffffff')
            .opacity(0.8)
          Text(`${this.score}`)
            .fontSize(22 * this.si.scaleFactor)
            .fontColor('#ffeb3b')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding(15 * this.si.scaleFactor)

        Row() {
          Text('⚡ 双发')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor('#ffffff')
            .opacity(0.8)
          Text(this.doubleShot ? '激活' : '未激活')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor(this.doubleShot ? '#4caf50' : '#888888')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding(15 * this.si.scaleFactor)

        Row() {
          Text('💥 全屏清除')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor('#ffffff')
            .opacity(0.8)
          Text(this.clearScreenCooldown > 0 ? `冷却 ${(this.clearScreenCooldown / 60).toFixed(1)}s` : '就绪')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor(this.clearScreenCooldown > 0 ? '#888888' : '#4caf50')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding(15 * this.si.scaleFactor)

        Divider().color('#333333').margin(10 * this.si.scaleFactor)

        Row() {
          Text('📱 设备')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor('#ffffff')
            .opacity(0.8)
          Text(this.deviceType === 'tablet' ? '平板' : this.deviceType === 'foldable' ? '折叠屏' : '手机')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor('#00e5ff')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding(15 * this.si.scaleFactor)

        Row() {
          Text('📐 布局')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor('#ffffff')
            .opacity(0.8)
          Text(this.isLandscape ? '横屏' : '竖屏')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor('#00e5ff')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding(15 * this.si.scaleFactor)

        Row() {
          Text('🔄 流转')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor('#ffffff')
            .opacity(0.8)
          Text(this.migrationStatus === 'none' ? '待命' : this.migrationStatus === 'saving' ? '保存中' : '恢复中')
            .fontSize(22 * this.si.scaleFactor)
            .fontColor(this.migrationStatus === 'none' ? '#4caf50' : '#1565c0')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding(15 * this.si.scaleFactor)
      }
      .width('100%')
      .backgroundColor('#1a1a2e')
      .borderRadius(15 * this.si.scaleFactor)
      .padding(10 * this.si.scaleFactor)

      Column() {
        Text('🎮 操作说明')
          .fontSize(24 * this.si.scaleFactor)
          .fontColor('#00e5ff')
          .fontWeight(FontWeight.Bold)
          .margin({ top: 20 * this.si.scaleFactor, bottom: 10 * this.si.scaleFactor })

        Text('🔫 普通射击')
          .fontSize(18 * this.si.scaleFactor)
          .fontColor('#ffffff')
          .opacity(0.7)
          .margin(5 * this.si.scaleFactor)
        Text('💥 多段射击')
          .fontSize(18 * this.si.scaleFactor)
          .fontColor('#ffffff')
          .opacity(0.7)
          .margin(5 * this.si.scaleFactor)
        Text('⚡ 全屏清除 (10s冷却)')
          .fontSize(18 * this.si.scaleFactor)
          .fontColor('#ffffff')
          .opacity(0.7)
          .margin(5 * this.si.scaleFactor)
        Text('🔄 流转到其他设备继续游戏')
          .fontSize(18 * this.si.scaleFactor)
          .fontColor('#ffffff')
          .opacity(0.7)
          .margin(5 * this.si.scaleFactor)
      }
      .width('100%')
      .padding(15 * this.si.scaleFactor)
    }
    .width('100%')
    .height('100%')
    .padding(20 * this.si.scaleFactor)
    .backgroundColor('#0d0d1a')
  }

  build() {
    Stack() {
      Column() {
        this.gameCanvas()
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.si.safeAreaTop })

      if (this.deviceType === 'tablet' && this.isLandscape) {
        Column() {
          this.infoPanel()
        }
        .width(this.si.screenWidth * 0.25)
        .height('100%')
        .offset({ x: this.si.screenWidth * 0.5 - this.si.screenWidth * 0.125, y: 0 })
        .hitTestBehavior(HitTestMode.Transparent)
      }

      Column() {
        this.controlPanel()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Bottom)
  }
}
