import { forwardRef } from "react"
import { cn } from "@/lib/utils"

interface MaskedIconProps extends React.HTMLAttributes<HTMLSpanElement> {
  src?: string
  sizeClassName?: string
}

export const MaskedIcon = forwardRef<HTMLSpanElement, MaskedIconProps>(
  ({ src, sizeClassName = "size-4", className, ...rest }, ref) => {
    if (!src) return null

    return (
      <span
        ref={ref}
        aria-hidden
        className={cn(sizeClassName, className)}
        style={{
          WebkitMaskImage: `url(${src})`,
          maskImage: `url(${src})`,
          WebkitMaskRepeat: "no-repeat",
          maskRepeat: "no-repeat",
          WebkitMaskSize: "contain",
          maskSize: "contain",
          WebkitMaskPosition: "center",
          maskPosition: "center",
          backgroundColor: "currentColor",
        }}
        {...rest}
      />
    )
  },
)

MaskedIcon.displayName = "MaskedIcon"
