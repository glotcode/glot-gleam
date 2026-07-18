export const cookieNoticeStorageKey: string;
export function noticeWasSeen(storage: Storage | null | undefined): boolean;
export function rememberNotice(storage: Storage | null | undefined): void;
export function forgetNotice(storage: Storage | null | undefined): void;
