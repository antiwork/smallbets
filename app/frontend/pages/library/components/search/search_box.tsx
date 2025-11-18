import { forwardRef, type ChangeEvent, type FormEvent } from "react"

import { cn } from "@/lib/utils"
import { Input } from "@/components/ui/input"

export interface SearchBoxProps {
  iconSrc?: string
  value: string
  onChange: (value: string) => void
  onSubmit?: (value: string) => void
  containerClassName?: string
  inputId?: string
  autoFocus?: boolean
}

export const SearchBox = forwardRef<HTMLInputElement, SearchBoxProps>(
  function SearchBox(
    {
      iconSrc,
      value,
      onChange,
      onSubmit,
      containerClassName,
      inputId,
      autoFocus,
    },
    ref,
  ) {
    const handleChange = (event: ChangeEvent<HTMLInputElement>) => {
      onChange(event.target.value)
    }

    const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault()
      onSubmit?.(value)
    }

    return (
      <form
        role="search"
        className={cn(
          "relative mr-13 ml-auto flex w-full max-w-xs lg:mr-18",
          containerClassName,
        )}
        onSubmit={handleSubmit}
      >
        <div className="w-full">
          <label className="sr-only" htmlFor={inputId ?? "library-search"}>
            Search library
          </label>
          <Input
            id={inputId ?? "library-search"}
            type="search"
            icon={iconSrc}
            placeholder="Search sessions, instructors, topics"
            aria-label="Search library"
            autoComplete="off"
            value={value}
            onChange={handleChange}
            ref={ref}
            autoFocus={autoFocus}
          />
        </div>
      </form>
    )
  },
)
