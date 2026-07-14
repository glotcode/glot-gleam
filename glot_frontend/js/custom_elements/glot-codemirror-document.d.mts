import type { EditorState, TransactionSpec } from "@codemirror/state";

export interface DocumentRevisions {
  localRevision: number;
  acknowledgedRevision: number;
  externalRevision: number;
  renderedRevision: number;
  renderedExternalRevision: number;
}

export function shouldApplyDocumentValue(revisions: DocumentRevisions): boolean;
export function documentUpdate(state: EditorState, incoming: string): TransactionSpec;
