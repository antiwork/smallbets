import type { ButtonHTMLAttributes } from "react"
import type { CarouselApi } from "@/components/ui/carousel"

interface ArrowButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  direction: "prev" | "next"
  iconPathD: string
}

function ArrowButton({
  direction,
  iconPathD,
  className,
  ...props
}: ArrowButtonProps) {
  const sideClass =
    direction === "prev"
      ? "left-[-11vw] xl:left-[-8vw] 2xl:left-[-12vw]"
      : "right-[-11vw] xl:right-[-8vw] 2xl:right-[-12vw]"
  const iconTranslateClass =
    direction === "prev"
      ? "group-hover:-translate-x-1"
      : "group-hover:translate-x-1"
  return (
    <button
      type="button"
      className={[
        "group absolute top-1/2 z-0 hidden size-25 -translate-y-1/2 items-center justify-center bg-neutral-100 transition-all duration-200 ease-out hover:bg-neutral-200 hover:shadow-none! focus-visible:ring-2 focus-visible:ring-[#00ADEF] focus-visible:outline-none xl:flex dark:bg-neutral-800 dark:hover:bg-neutral-700 dark:focus-visible:ring-[#00ADEF]",
        className,
        sideClass,
      ]
        .filter(Boolean)
        .join(" ")}
      tabIndex={-1}
      {...props}
    >
      <svg
        viewBox="0 0 24 24"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden
        className={[
          "size-9 transition-transform duration-200 ease-out",
          iconTranslateClass,
        ].join(" ")}
      >
        <path
          d={iconPathD}
          className="fill-neutral-900 transition-colors dark:fill-white"
        />
      </svg>
    </button>
  )
}

interface NavButtonsProps {
  api: CarouselApi | undefined
  onInteract?: () => void
}

const PATH_PREV =
  "M9.62132 12L8.56066 13.1112C7.97487 13.7248 7.02513 13.7248 6.43934 13.1112C5.85355 12.4975 5.85355 11.5025 6.43934 10.8888L15.4393 1.46026C16.0251 0.84658 16.9749 0.84658 17.5607 1.46026C18.1464 2.07394 18.1464 3.06891 17.5607 3.6826L9.62132 12L17.5607 20.3174C18.1464 20.9311 18.1464 21.9261 17.5607 22.5397C16.9749 23.1534 16.0251 23.1534 15.4393 22.5397L6.43934 13.1112C5.85355 12.4975 5.85355 11.5025 6.43934 10.8888C7.02513 10.2751 7.97487 10.2751 8.56066 10.8888L9.62132 12Z"
const PATH_NEXT =
  "M14.3787 12L15.4393 10.8888C16.0251 10.2752 16.9749 10.2752 17.5607 10.8888C18.1464 11.5025 18.1464 12.4975 17.5607 13.1112L8.56066 22.5397C7.97487 23.1534 7.02512 23.1534 6.43934 22.5397C5.85355 21.9261 5.85355 20.9311 6.43934 20.3174L14.3787 12L6.43934 3.6826C5.85355 3.06892 5.85355 2.07395 6.43934 1.46026C7.02513 0.846584 7.97487 0.846584 8.56066 1.46026L17.5607 10.8888C18.1464 11.5025 18.1464 12.4975 17.5607 13.1112C16.9749 13.7249 16.0251 13.7249 15.4393 13.1112L14.3787 12Z"

export function NavButtons({ api, onInteract }: NavButtonsProps) {
  return (
    <>
      <ArrowButton
        direction="prev"
        aria-label="Previous slide"
        onClick={() => {
          onInteract?.()
          api?.scrollPrev()
        }}
        iconPathD={PATH_PREV}
      />
      <ArrowButton
        direction="next"
        aria-label="Next slide"
        onClick={() => {
          onInteract?.()
          api?.scrollNext()
        }}
        iconPathD={PATH_NEXT}
      />
    </>
  )
}
