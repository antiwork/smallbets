import { DownloadMenu } from "./download-menu"

interface FullscreenInfoBarProps {
  title: string
  creator: string
  vimeoId: string
  downloadPath?: string
}

export function FullscreenInfoBar({
  title,
  creator,
  vimeoId,
  downloadPath,
}: FullscreenInfoBarProps) {
  return (
    <div className="bg-background text-foreground flex h-[var(--bar-h)] items-center justify-between border-t border-transparent px-4 pb-[calc(env(safe-area-inset-bottom))] shadow-[0_-1px_0_0_var(--control-border)] md:px-6">
      <div className="min-w-0 pr-3">
        <h2 className="truncate text-lg font-medium">{title}</h2>
        <p className="library-muted-light truncate text-sm">{creator}</p>
      </div>
      <DownloadMenu
        vimeoId={vimeoId}
        downloadPath={downloadPath}
        title={title}
      />
    </div>
  )
}
