// Index.ets

// 位置与尺寸接口
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
  constructor(x: number, y: number) {
    super();
    this.width = 35;
    this.height = 35;
    this.x = x;
    this.y = y;
  }
}

@Entry
@Component
struct GamePage {
  // 战机属性
  @State playerX: number = 180;
  @State playerY: number = 600;
  private playerWidth: number = 45;
  private playerHeight: number = 45;
  @State playerHp: number = 5;
  @State score: number = 0;
  @State gameOver: boolean = false;

  // 子弹列表
  @State bullets: Bullet[] = [];
  // 敌机列表
  @State enemies: Enemy[] = [];

  // 射击冷却
  private shootCooldown: number = 0;
  // 游戏循环ID
  private intervalId: number = -1;

  // 移动状态标志（由触摸按钮控制）
  private leftPressed: boolean = false;
  private rightPressed: boolean = false;
  private upPressed: boolean = false;
  private downPressed: boolean = false;

  aboutToAppear() {
    this.startGameLoop();
  }

  aboutToDisappear() {
    if (this.intervalId !== -1) {
      clearInterval(this.intervalId);
    }
  }

  startGameLoop() {
    const callback: () => void = () => {
      if (this.gameOver) return;
      this.updateGame();
    };
    this.intervalId = setInterval(callback, 30);
  }

  updateGame() {
    // 1. 根据按下的移动按钮更新战机位置
    const step: number = 8;
    if (this.leftPressed && this.playerX > 10) {
      this.playerX -= step;
    }
    if (this.rightPressed && this.playerX < 350) {
      this.playerX += step;
    }
    if (this.upPressed && this.playerY > 50) {
      this.playerY -= step;
    }
    if (this.downPressed && this.playerY < 700) {
      this.playerY += step;
    }

    // 2. 射击冷却减少
    if (this.shootCooldown > 0) {
      this.shootCooldown--;
    }

    // 3. 子弹移动
    for (let i: number = 0; i < this.bullets.length; i++) {
      const bullet: Bullet = this.bullets[i];
      bullet.y -= bullet.speed;
      if (bullet.y + bullet.height < 0) {
        this.bullets.splice(i, 1);
        i--;
      }
    }

    // 4. 敌机移动
    for (let i: number = 0; i < this.enemies.length; i++) {
      const enemy: Enemy = this.enemies[i];
      enemy.y += enemy.speed;
      if (enemy.y > 850) {
        this.enemies.splice(i, 1);
        i--;
      }
    }

    // 5. 子弹 vs 敌机碰撞
    for (let i: number = 0; i < this.bullets.length; i++) {
      const bullet: Bullet = this.bullets[i];
      for (let j: number = 0; j < this.enemies.length; j++) {
        const enemy: Enemy = this.enemies[j];
        if (this.checkCollision(bullet, enemy)) {
          this.bullets.splice(i, 1);
          this.enemies.splice(j, 1);
          this.score++;
          i--;
          break;
        }
      }
    }

    // 6. 战机 vs 敌机碰撞（掉血）
    for (let i: number = 0; i < this.enemies.length; i++) {
      const enemy: Enemy = this.enemies[i];
      if (this.checkPlayerCollision(enemy)) {
        this.playerHp--;
        this.enemies.splice(i, 1);
        i--;
        if (this.playerHp <= 0) {
          this.gameOver = true;
          break;
        }
      }
    }

    // 7. 随机生成敌机
    if (Math.random() < 0.02 && this.enemies.length < 8) {
      const randX: number = Math.random() * 330;
      const newEnemy: Enemy = new Enemy(randX, -40);
      this.enemies.push(newEnemy);
    }
  }

  // 碰撞检测（两个实体）
  checkCollision(a: Entity, b: Entity): boolean {
    const aRight: number = a.x + a.width;
    const bRight: number = b.x + b.width;
    const aBottom: number = a.y + a.height;
    const bBottom: number = b.y + b.height;
    return !(aRight < b.x || bRight < a.x || aBottom < b.y || bBottom < a.y);
  }

  // 玩家碰撞检测
  checkPlayerCollision(enemy: Enemy): boolean {
    const playerRight: number = this.playerX + this.playerWidth;
    const enemyRight: number = enemy.x + enemy.width;
    const playerBottom: number = this.playerY + this.playerHeight;
    const enemyBottom: number = enemy.y + enemy.height;
    return !(playerRight < enemy.x || enemyRight < this.playerX ||
      playerBottom < enemy.y || enemyBottom < this.playerY);
  }

  // 开火方法（由按钮调用）
  fire() {
    if (this.gameOver) return;
    if (this.shootCooldown <= 0) {
      const bulletX: number = this.playerX + this.playerWidth / 2 - 3;
      const bulletY: number = this.playerY - 10;
      const newBullet: Bullet = new Bullet(bulletX, bulletY);
      this.bullets.push(newBullet);
      this.shootCooldown = 15;
    }
  }

  // 处理移动按钮的触摸事件（按下/抬起）
  handleMoveTouch(button: 'left' | 'right' | 'up' | 'down', isPressed: boolean) {
    if (this.gameOver) return;
    switch (button) {
      case 'left':
        this.leftPressed = isPressed;
        break;
      case 'right':
        this.rightPressed = isPressed;
        break;
      case 'up':
        this.upPressed = isPressed;
        break;
      case 'down':
        this.downPressed = isPressed;
        break;
    }
  }

  restartGame() {
    this.playerHp = 5;
    this.score = 0;
    this.bullets = [];
    this.enemies = [];
    this.playerX = 180;
    this.playerY = 600;
    this.gameOver = false;
    this.shootCooldown = 0;
    // 重置所有移动标志
    this.leftPressed = false;
    this.rightPressed = false;
    this.upPressed = false;
    this.downPressed = false;
  }

  build() {
    Stack() {
      // 游戏背景区域
      Column() {
        // 游戏画布区域（显示战机、子弹、敌机）
        Stack() {
          // 背景
          Rect()
            .width('100%')
            .height('100%')
            .fill('#1a1a2e')

          // 战机
          if (!this.gameOver) {
            Rect()
              .width(this.playerWidth)
              .height(this.playerHeight)
              .position({ x: this.playerX, y: this.playerY })
              .borderRadius(20)
              .fill('#00bcd4')
          }

          // 子弹
          ForEach(this.bullets, (bullet: Bullet) => {
            Rect()
              .width(bullet.width)
              .height(bullet.height)
              .fill('#ffeb3b')
              .position({ x: bullet.x, y: bullet.y })
              .borderRadius(3)
          }, (bullet: Bullet) => `bullet_${bullet.x}_${bullet.y}`)

          // 敌机
          ForEach(this.enemies, (enemy: Enemy) => {
            Rect()
              .width(enemy.width)
              .height(enemy.height)
              .position({ x: enemy.x, y: enemy.y })
              .fill('#f44336')
              .borderRadius(5)
          }, (enemy: Enemy) => `enemy_${enemy.x}_${enemy.y}`)

          // 血量和得分显示
          Row() {
            Text(`❤️ ${this.playerHp}`)
              .fontSize(24)
              .fontColor('#FFFFFF')
              .margin(10)
            Text(`🎯 ${this.score}`)
              .fontSize(24)
              .fontColor('#FFFFFF')
              .margin(10)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .padding(10)
          .position({ x: 0, y: 0 })

          // 游戏结束遮罩
          if (this.gameOver) {
            Column() {
              Text('GAME OVER')
                .fontSize(36)
                .fontColor('#FF5252')
                .margin(20)
              Text(`最终得分: ${this.score}`)
                .fontSize(24)
                .fontColor('#FFFFFF')
              Button('重新开始')
                .margin(30)
                .onClick(() => {
                  this.restartGame();
                })
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor('rgba(0,0,0,0.7)')
          }
        }
        .width('100%')
        .layoutWeight(1)  // 占据剩余空间，让按钮区域在底部

        // 底部按钮区域
        Column() {
          // 第一行：上下
          Row() {
            Button('↑')
              .width(70)
              .height(70)
              .fontSize(30)
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.handleMoveTouch('up', true);
                } else if (event.type === TouchType.Up) {
                  this.handleMoveTouch('up', false);
                }
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          // 第二行：左右 + 开火
          Row() {
            Button('←')
              .width(70)
              .height(70)
              .fontSize(30)
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.handleMoveTouch('left', true);
                } else if (event.type === TouchType.Up) {
                  this.handleMoveTouch('left', false);
                }
              })
              .margin(20)

            Button('↓')
              .width(70)
              .height(70)
              .fontSize(30)
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.handleMoveTouch('down', true);
                } else if (event.type === TouchType.Up) {
                  this.handleMoveTouch('down', false);
                }
              })
              .margin(20)

            Button('→')
              .width(70)
              .height(70)
              .fontSize(30)
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.handleMoveTouch('right', true);
                } else if (event.type === TouchType.Up) {
                  this.handleMoveTouch('right', false);
                }
              })
              .margin(20)

            Button('🔫 开火')
              .width(100)
              .height(70)
              .fontSize(24)
              .onClick(() => {
                this.fire();
              })
              .margin(20)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding({ bottom: 20 })
        .backgroundColor('#2d2d3a')
      }
      .width('100%')
      .height('100%')
    }
  }
}