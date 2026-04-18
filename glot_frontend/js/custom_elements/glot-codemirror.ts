import { EditorState, Compartment, type Extension } from "@codemirror/state";
import { EditorView, keymap } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { lineNumbers, highlightActiveLineGutter } from "@codemirror/view";
import { highlightActiveLine, drawSelection, dropCursor } from "@codemirror/view";
import { defaultHighlightStyle, indentOnInput, syntaxHighlighting } from "@codemirror/language";
import { bracketMatching } from "@codemirror/language";
import { closeBrackets, closeBracketsKeymap } from "@codemirror/autocomplete";
import { highlightSelectionMatches, searchKeymap } from "@codemirror/search";
import { autocompletion, completionKeymap } from "@codemirror/autocomplete";
import { rectangularSelection } from "@codemirror/view";
import { indentWithTab } from "@codemirror/commands";
import { StreamLanguage } from "@codemirror/language"

// Minimal "basic setup" (avoids depending on codemirror meta-package)
const basicSetup: Extension = [
  lineNumbers(),
  highlightActiveLineGutter(),
  history(),
  drawSelection(),
  dropCursor(),
  indentOnInput(),
  bracketMatching(),
  closeBrackets(),
  autocompletion(),
  rectangularSelection(),
  highlightActiveLine(),
  highlightSelectionMatches(),
  syntaxHighlighting(defaultHighlightStyle),
  keymap.of([
    ...closeBracketsKeymap,
    ...defaultKeymap,
    ...searchKeymap,
    ...historyKeymap,
    ...completionKeymap,
    indentWithTab
  ])
];

const languageMap: Record<string, () => Promise<Extension>> = {
  bash: async () => {
    const module = await import('@codemirror/legacy-modes/mode/shell');
    return StreamLanguage.define(module.shell);
  },
  c: async () => {
    const module = await import('@codemirror/legacy-modes/mode/clike');
    return StreamLanguage.define(module.c);
  },
  clisp: async () => {
    const module = await import('@codemirror/legacy-modes/mode/commonlisp');
    return StreamLanguage.define(module.commonLisp);
  },
  clojure: async () => {
    const module = await import('@codemirror/legacy-modes/mode/clojure');
    return StreamLanguage.define(module.clojure);
  },
  cobol: async () => {
    const module = await import('@codemirror/legacy-modes/mode/cobol');
    return StreamLanguage.define(module.cobol);
  },
  coffeescript: async () => {
    const module = await import('@codemirror/legacy-modes/mode/coffeescript');
    return StreamLanguage.define(module.coffeeScript);
  },
  cpp: async () => {
    const module = await import('@codemirror/lang-cpp');
    return module.cpp();
  },
  crystal: async () => {
    const module = await import('@codemirror/legacy-modes/mode/crystal');
    return StreamLanguage.define(module.crystal);
  },
  csharp: async () => {
    const module = await import('@codemirror/legacy-modes/mode/clike');
    return StreamLanguage.define(module.csharp);
  },
  d: async () => {
    const module = await import('@codemirror/legacy-modes/mode/d');
    return StreamLanguage.define(module.d);
  },
  dart: async () => {
    const module = await import('@codemirror/legacy-modes/mode/clike');
    return StreamLanguage.define(module.dart);
  },
  elm: async () => {
    const module = await import('@codemirror/legacy-modes/mode/elm');
    return StreamLanguage.define(module.elm);
  },
  elixir: async () => {
    const module = await import('codemirror-lang-elixir');
    return module.elixir();
  },
  erlang: async () => {
    const module = await import('@codemirror/legacy-modes/mode/erlang');
    return StreamLanguage.define(module.erlang);
  },
  fsharp: async () => {
    const module = await import('@codemirror/legacy-modes/mode/mllike');
    return StreamLanguage.define(module.fSharp);
  },
  go: async () => {
    const module = await import('@codemirror/lang-go');
    return module.go();
  },
  groovy: async () => {
    const module = await import('@codemirror/legacy-modes/mode/groovy');
    return StreamLanguage.define(module.groovy);
  },
  guile: async () => {
    const module = await import('@codemirror/legacy-modes/mode/scheme');
    return StreamLanguage.define(module.scheme);
  },
  haskell: async () => {
    const module = await import('@codemirror/legacy-modes/mode/haskell');
    return StreamLanguage.define(module.haskell);
  },
  java: async () => {
    const module = await import('@codemirror/lang-java');
    return module.java();
  },
  javascript: async () => {
    const module = await import('@codemirror/lang-javascript');
    return module.javascript();
  },
  julia: async () => {
    const module = await import('@plutojl/lang-julia');
    return module.julia();
  },
  kotlin: async () => {
    const module = await import('@codemirror/legacy-modes/mode/clike');
    return StreamLanguage.define(module.kotlin);
  },
  lua: async () => {
    const module = await import('@codemirror/legacy-modes/mode/lua');
    return StreamLanguage.define(module.lua);
  },
  nix: async () => {
    const module = await import('@replit/codemirror-lang-nix');
    return module.nix();
  },
  ocaml: async () => {
    const module = await import('@codemirror/legacy-modes/mode/mllike');
    return StreamLanguage.define(module.oCaml);
  },
  pascal: async () => {
    const module = await import('@codemirror/legacy-modes/mode/pascal');
    return StreamLanguage.define(module.pascal);
  },
  perl: async () => {
    const module = await import('@codemirror/legacy-modes/mode/perl');
    return StreamLanguage.define(module.perl);
  },
  php: async () => {
    const module = await import('@codemirror/lang-php');
    return module.php();
  },
  python: async () => {
    const module = await import('@codemirror/lang-python');
    return module.python();
  },
  ruby: async () => {
    const module = await import('@codemirror/legacy-modes/mode/ruby');
    return StreamLanguage.define(module.ruby);
  },
  rust: async () => {
    const module = await import('@codemirror/lang-rust');
    return module.rust();
  },
  scala: async () => {
    const module = await import('@codemirror/legacy-modes/mode/clike');
    return StreamLanguage.define(module.scala);
  },
  swift: async () => {
    const module = await import('@codemirror/legacy-modes/mode/swift');
    return StreamLanguage.define(module.swift);
  },
  typescript: async () => {
    const module = await import('@codemirror/lang-javascript');
    return module.javascript({ typescript: true });
  },
};

type ChangeEventDetail = { value: string };

export class GlotCodeMirror extends HTMLElement {
  static get observedAttributes() {
    return ["value", "language", "disabled"];
  }

  private _shadow: ShadowRoot;
  private _container: HTMLDivElement;
  private _view: EditorView | null = null;

  private _valueCache = "";
  private _languageName = "javascript";
  private _updatingFromOutside = false;

  private _language = new Compartment();
  private _editable = new Compartment();

  constructor() {
    super();

    this._valueCache = this.getAttribute("value") ?? "";
    this._languageName = (this.getAttribute("language") ?? "javascript").toLowerCase();

    this._shadow = this.attachShadow({ mode: "open" });

    const style = document.createElement("style");
    style.textContent = `
      :host {
        display: block;
      }

      .cm-wrapper, .cm-gutter {
        min-height: 200px !important;
      }

      .cm-gutter {
        min-width: 33px;
      }

      .cm-scroller {
        overflow: auto;
      }

      .cm-wrapper {
        border: 1px solid #e5e7eb;
        border-radius: 8px;
        overflow: clip;
        font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", "Apple Color Emoji", "Segoe UI Emoji";
      }

      .cm-editor {
        height: 100%;
      }
    `;

    this._container = document.createElement("div");
    this._container.className = "cm-wrapper";

    this._shadow.append(style, this._container);
  }

  connectedCallback() {
    if (this._view) return;

    const editableExt = EditorView.editable.of(!this.hasAttribute("disabled"));

    const state = EditorState.create({
      doc: this._valueCache,
      extensions: [
        basicSetup,
        this._language.of([]),
        this._editable.of(editableExt),
        EditorView.updateListener.of((update) => {
          if (!update.docChanged) return;
          const next = update.state.doc.toString();
          this._valueCache = next;
          if (this._updatingFromOutside) return;
          // Emit a bubbling, composed CustomEvent so frameworks (like Elm) can listen.
          this.dispatchEvent(
            new CustomEvent<ChangeEventDetail>("change", {
              detail: { value: next },
              bubbles: true,
              composed: true
            })
          );
        })
      ]
    });

    this._view = new EditorView({
      state,
      parent: this._container
    });

    // Load language extension async
    this._getLanguageExtension(this._languageName)?.then((ext) => {
      if (this._view && ext) {
        this._view.dispatch({ effects: this._language.reconfigure(ext) });
      }
    })
  }

  disconnectedCallback() {
    if (this._view) {
      this._view.destroy();
      this._view = null;
    }
  }

  async attributeChangedCallback(name: string, _oldVal: string | null, newVal: string | null) {
    // Cache until the editor is ready
    if (!this._view) {
      if (name === "value") this._valueCache = newVal ?? "";
      if (name === "language") this._languageName = (newVal ?? "javascript").toLowerCase();
      return;
    }

    if (name === "value") {
      const incoming = newVal ?? "";
      if (incoming !== this.value) {
        this._updatingFromOutside = true;
        this._view.dispatch({
          changes: { from: 0, to: this._view.state.doc.length, insert: incoming }
        });
        this._updatingFromOutside = false;
      }
      return;
    }

    if (name === "language") {
      const ext = await this._getLanguageExtension((newVal ?? "javascript").toLowerCase());
      this._view.dispatch({ effects: this._language.reconfigure(ext ?? []) });
      return;
    }

    if (name === "disabled") {
      const editable = !this.hasAttribute("disabled");
      this._view.dispatch({
        effects: this._editable.reconfigure(EditorView.editable.of(editable))
      });
      return;
    }
  }

  // Public API
  get value(): string {
    if (!this._view) return this._valueCache;
    return this._view.state.doc.toString();
  }
  set value(v: string) {
    this.setAttribute("value", v ?? "");
  }

  get language(): string {
    return this._languageName;
  }
  set language(name: string) {
    this.setAttribute("language", name);
  }

  get disabled(): boolean {
    return this.hasAttribute("disabled");
  }
  set disabled(flag: boolean) {
    if (flag) this.setAttribute("disabled", "");
    else this.removeAttribute("disabled");
  }

  // Helpers
  private _getLanguageExtension(name: string): Promise<Extension> | null {
    const factory = languageMap[name];
    if (!factory) {
      return null
    }

    return factory()
  }
}

customElements.define("glot-codemirror", GlotCodeMirror);

declare global {
  interface HTMLElementTagNameMap {
    "glot-codemirror": GlotCodeMirror;
  }
}
