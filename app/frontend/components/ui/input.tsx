import { forwardRef, type ReactNode } from "react"

import { cn } from "@/lib/utils"
import { MaskedIcon } from "./masked-icon"

interface InputProps extends React.ComponentProps<"input"> {
  icon?: ReactNode | string
}

const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, icon, ...props }, ref) => {
    const renderIcon = () => {
      if (!icon) return null
      if (typeof icon === "string") {
        return <MaskedIcon src={icon} />
      }
      return icon
    }

    return (
      <div className="relative flex w-full items-center pt-[1px]">
        {icon ? (
          <span className="text-muted-foreground pointer-events-none absolute left-3 inline-flex size-4 items-center justify-center">
            {renderIcon()}
          </span>
        ) : null}
        <input
          ref={ref}
          type={type}
          data-slot="input"
          className={cn(
            "file:text-foreground placeholder:text-muted-foreground selection:bg-primary selection:text-primary-foreground bg-background dark:bg-input/30 border-input h-9 w-full min-w-0 rounded-md px-3 py-1 text-base shadow-[0_0_0_1px_var(--control-border)] transition-[color,box-shadow] outline-none file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm",
            "focus:[box-shadow:0_0_0_1px_var(--color-selected-dark),0_0_0_var(--hover-size)_var(--color-selected-dark)!important] focus:[filter:var(--hover-filter)] focus:[--hover-color:var(--color-selected-dark)] focus-visible:ring-0",
            "aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive",
            icon ? "pl-10" : undefined,
            className,
          )}
          {...props}
        />
      </div>
    )
  },
)

Input.displayName = "Input"

export { Input }
