/** Tiny typed-less event emitter. `on` returns an unsubscribe function. */
export class Emitter {
  #handlers = new Map();

  on(event, handler) {
    let set = this.#handlers.get(event);
    if (!set) this.#handlers.set(event, (set = new Set()));
    set.add(handler);
    return () => set.delete(handler);
  }

  emit(event, payload) {
    const set = this.#handlers.get(event);
    if (!set) return;
    for (const handler of [...set]) {
      try {
        handler(payload);
      } catch (error) {
        console.error(`[avatar] "${event}" handler failed`, error);
      }
    }
  }

  clear() {
    this.#handlers.clear();
  }
}
