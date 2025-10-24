import type { ChangeEvent } from "react"

export interface SearchBoxProps {
  iconSrc?: string
  value: string
  onChange: (value: string) => void
}

export function SearchBox({ iconSrc, value, onChange }: SearchBoxProps) {
  const handleChange = (event: ChangeEvent<HTMLInputElement>) => {
    onChange(event.target.value)
  }

  const baseClasses =
    "w-full h-9 rounded-md border border-input bg-background px-3 py-1 text-sm text-foreground placeholder:text-muted-foreground transition focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm dark:bg-input/30"
  const inputClassName = iconSrc ? `${baseClasses} pl-10` : baseClasses

  return (
    <div className="relative mr-18 ml-auto flex w-full max-w-xs">
      <div className="w-full pt-0.5">
        <label className="sr-only" htmlFor="library-search">
          Search library
        </label>
        <input
          id="library-search"
          type="search"
          className={inputClassName}
          placeholder="Search sessions, instructors, topics"
          aria-label="Search library"
          autoComplete="off"
          value={value}
          onChange={handleChange}
        />
        {iconSrc ? (
          <span
            aria-hidden
            className="text-muted-foreground pointer-events-none absolute inset-y-0 left-3 flex items-center"
          >
            <span
              className="size-4"
              style={{
                WebkitMaskImage: `url(${iconSrc})`,
                maskImage: `url(${iconSrc})`,
                WebkitMaskRepeat: "no-repeat",
                maskRepeat: "no-repeat",
                WebkitMaskSize: "contain",
                maskSize: "contain",
                WebkitMaskPosition: "center",
                maskPosition: "center",
                backgroundColor: "currentColor",
              }}
            />
          </span>
        ) : null}
      </div>
    </div>
  )
}
