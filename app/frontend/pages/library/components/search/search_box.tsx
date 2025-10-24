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
    "w-full h-9 rounded-md border-0 appearance-none shadow-[0_0_0_1px_var(--control-border)] bg-background pb-1.5 px-3 pt-1 text-sm text-foreground placeholder:text-muted-foreground outline-none transition-[filter,box-shadow,border-color] duration-200 focus:[--hover-color:var(--color-selected-dark)] focus:[--outline-size:0] focus:[filter:var(--hover-filter)] focus:[box-shadow:0_0_0_1px_var(--hover-color),0_0_0_var(--hover-size)_var(--hover-color)] focus:hover:[--hover-color:var(--color-selected-dark)] focus:hover:[filter:var(--hover-filter)] focus:hover:[box-shadow:0_0_0_1px_var(--control-border),0_0_0_var(--hover-size)_var(--hover-color)] disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm dark:bg-input/30"
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
            className="text-muted-foreground pointer-events-none absolute inset-y-0 top-[1px] left-3 flex items-center"
          >
            <span
              className="size-3.5"
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
