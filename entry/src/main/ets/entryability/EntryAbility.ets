import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export interface GameState {
  playerX: number;
  playerY: number;
  playerHp: number;
  score: number;
  gameOver: boolean;
  gameStarted: boolean;
  doubleShot: boolean;
  doubleShotTimer: number;
  clearScreenCooldown: number;
}

let savedGameState: GameState | null = null;

export function saveGameState(state: GameState): void {
  savedGameState = state;
  hilog.info(DOMAIN, TAG, 'Game state saved');
}

export function getSavedGameState(): GameState | null {
  return savedGameState;
}

export function clearSavedGameState(): void {
  savedGameState = null;
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');

    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      if (want.parameters) {
        const state: GameState = {
          playerX: Number(want.parameters['playerX']) || 180,
          playerY: Number(want.parameters['playerY']) || 600,
          playerHp: Number(want.parameters['playerHp']) || 5,
          score: Number(want.parameters['score']) || 0,
          gameOver: Number(want.parameters['gameOver']) === 1,
          gameStarted: Number(want.parameters['gameStarted']) === 1,
          doubleShot: Number(want.parameters['doubleShot']) === 1,
          doubleShotTimer: Number(want.parameters['doubleShotTimer']) || 0,
          clearScreenCooldown: Number(want.parameters['clearScreenCooldown']) || 0,
        };
        savedGameState = state;
        hilog.info(DOMAIN, TAG, 'Game state restored from continuation: score=%{public}d', state.score);
      }
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }

  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onContinue');
    if (savedGameState !== null) {
      wantParam['playerX'] = savedGameState.playerX as Object;
      wantParam['playerY'] = savedGameState.playerY as Object;
      wantParam['playerHp'] = savedGameState.playerHp as Object;
      wantParam['score'] = savedGameState.score as Object;
      wantParam['gameOver'] = (savedGameState.gameOver ? 1 : 0) as Object;
      wantParam['gameStarted'] = (savedGameState.gameStarted ? 1 : 0) as Object;
      wantParam['doubleShot'] = (savedGameState.doubleShot ? 1 : 0) as Object;
      wantParam['doubleShotTimer'] = savedGameState.doubleShotTimer as Object;
      wantParam['clearScreenCooldown'] = savedGameState.clearScreenCooldown as Object;
      hilog.info(DOMAIN, TAG, 'Game state serialized for migration: score=%{public}d', savedGameState.score);
      return AbilityConstant.OnContinueResult.AGREE;
    }
    hilog.info(DOMAIN, TAG, 'No game state to migrate');
    return AbilityConstant.OnContinueResult.REJECT;
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onNewWant');
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION && want.parameters) {
      const state: GameState = {
        playerX: Number(want.parameters['playerX']) || 180,
        playerY: Number(want.parameters['playerY']) || 600,
        playerHp: Number(want.parameters['playerHp']) || 5,
        score: Number(want.parameters['score']) || 0,
        gameOver: Number(want.parameters['gameOver']) === 1,
        gameStarted: Number(want.parameters['gameStarted']) === 1,
        doubleShot: Number(want.parameters['doubleShot']) === 1,
        doubleShotTimer: Number(want.parameters['doubleShotTimer']) || 0,
        clearScreenCooldown: Number(want.parameters['clearScreenCooldown']) || 0,
      };
      savedGameState = state;
      hilog.info(DOMAIN, TAG, 'Game state updated from new want: score=%{public}d', state.score);
    }
  }
}
