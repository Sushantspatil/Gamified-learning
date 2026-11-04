const KEY_MAP = {
  KeyW: 'forward',
  ArrowUp: 'forward',
  KeyS: 'back',
  ArrowDown: 'back',
  KeyA: 'left',
  ArrowLeft: 'left',
  KeyD: 'right',
  ArrowRight: 'right',
};

/**
 * WASD / arrow keys (+ Shift to run). Reads `event.code`, so it works on any
 * keyboard layout. Ignores typing in inputs and keys while a modifier other
 * than Shift is held. Call dispose() to remove the listeners.
 */
export class InputController {
  #down = new Set();
  #shift = false;
  #enabled = true;
  #onKeyDown = (event) => this.#handle(event, true);
  #onKeyUp = (event) => this.#handle(event, false);
  #onBlur = () => this.reset();
  #onVisibility = () => {
    if (document.hidden) this.reset();
  };

  constructor(target = window) {
    this.target = target;
    target.addEventListener('keydown', this.#onKeyDown);
    target.addEventListener('keyup', this.#onKeyUp);
    window.addEventListener('blur', this.#onBlur);
    document.addEventListener('visibilitychange', this.#onVisibility);
  }

  get enabled() {
    return this.#enabled;
  }

  set enabled(value) {
    this.#enabled = value;
    if (!value) this.reset();
  }

  /** x: -1 left .. 1 right, z: -1 back .. 1 forward, run: Shift held. */
  get axes() {
    const x = (this.#down.has('right') ? 1 : 0) - (this.#down.has('left') ? 1 : 0);
    const z = (this.#down.has('forward') ? 1 : 0) - (this.#down.has('back') ? 1 : 0);
    return { x, z, run: this.#shift, active: x !== 0 || z !== 0 };
  }

  reset() {
    this.#down.clear();
    this.#shift = false;
  }

  #handle(event, pressed) {
    if (!this.#enabled) return;
    if (event.code === 'ShiftLeft' || event.code === 'ShiftRight') {
      this.#shift = pressed;
      return;
    }
    const action = KEY_MAP[event.code];
    if (!action) return;
    if (pressed) {
      if (isTyping(event.target) || event.ctrlKey || event.metaKey || event.altKey) return;
      event.preventDefault(); // stop arrow keys from scrolling the page
      this.#down.add(action);
    } else {
      this.#down.delete(action);
    }
  }

  dispose() {
    this.target.removeEventListener('keydown', this.#onKeyDown);
    this.target.removeEventListener('keyup', this.#onKeyUp);
    window.removeEventListener('blur', this.#onBlur);
    document.removeEventListener('visibilitychange', this.#onVisibility);
    this.reset();
  }
}

function isTyping(element) {
  if (!element || !(element instanceof HTMLElement)) return false;
  const tag = element.tagName;
  return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || element.isContentEditable;
}
