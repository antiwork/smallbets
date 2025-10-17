import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "status" ]
  static classes = [ "urgent" ]
  static values = {
    targetTime: String,
    durationHours: Number
  }

  connect() {
    this.navElement = document.getElementById("nav");
    this.bannerHeight = this.element.offsetHeight;
    if (this.bannerHeight === 0) {
      const padding = 0.5 * parseFloat(getComputedStyle(document.documentElement).fontSize); 
      this.bannerHeight = parseFloat(getComputedStyle(this.element).lineHeight || getComputedStyle(document.documentElement).fontSize) + 2 * padding;
    }

    try {
      this.targetDate = new Date(this.targetTimeValue)
      this.endDate = new Date(this.targetDate.getTime() + this.durationHoursValue * 60 * 60 * 1000)

      this.updateBannerVisibility()
      this.interval = setInterval(() => {
        this.updateBannerVisibility()
      }, 1000)
    } catch (error) {
      console.error("Error in CountdownBannerController connect:", error)
      this.element.style.display = 'none'
      if (this.navElement) this.navElement.style.top = null;
    }
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
    if (this.navElement) this.navElement.style.top = null;
  }

  updateBannerVisibility() {
    const now = new Date();

    if (isNaN(this.targetDate.getTime()) || isNaN(this.endDate.getTime())) {
        console.error("Invalid date parsed. Hiding banner.");
        this.hideBanner();
        if (this.interval) clearInterval(this.interval);
        return;
    }

    const diff = this.targetDate - now;
    const twentyFourHoursInMillis = 24 * 60 * 60 * 1000;
    const twoHoursInMillis = 2 * 60 * 60 * 1000;
    
    // Hide if more than 24 hours away or if event is over
    if (diff > twentyFourHoursInMillis || now >= this.endDate) {
      this.hideBanner();
      if (now >= this.endDate && this.interval) {
        clearInterval(this.interval); // Stop interval only if event ended
      }
      return; // Don't proceed further if hidden
    }

    // --- Banner should be visible from here --- 
    this.showBanner();

    const isUrgent = diff < twoHoursInMillis;

    if (now >= this.targetDate) { // Event is live
      this.statusTarget.textContent = 'Live Now!';
      this.element.classList.add(this.urgentClass);
    } else { // Event hasn't started yet
      if (isUrgent) {
        // Less than 2 hours left: Show countdown
        this.updateCountdown(now);
        this.element.classList.add(this.urgentClass);
      } else {
        // Between 2 and 24 hours left: Show day + time
        const targetLocalDate = this.targetDate; // Already a Date object
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        const targetDay = new Date(targetLocalDate.getFullYear(), targetLocalDate.getMonth(), targetLocalDate.getDate());

        let dayPrefix = "Live on X"; // Default/Fallback
        if (targetDay.getTime() === today.getTime()) {
          dayPrefix = "Live on X today";
        } else if (targetDay.getTime() === tomorrow.getTime()) {
          dayPrefix = "Live on X tomorrow";
        } // Future dates > tomorrow are handled by the 24h check above
        
        const formattedTime = targetLocalDate.toLocaleString(undefined, { hour: 'numeric', minute: '2-digit' });
        this.statusTarget.textContent = `${dayPrefix} at ${formattedTime}`;
        this.element.classList.remove(this.urgentClass);
      }
    }
  }

  showBanner() {
    this.element.style.display = 'block'
    this.bannerHeight = this.element.offsetHeight;
    if (this.navElement && this.bannerHeight > 0) {
      this.navElement.style.top = `${this.bannerHeight}px`;
    }
  }

  hideBanner() {
    this.element.style.display = 'none'
    this.element.classList.remove(this.urgentClass)
    if (this.navElement) {
      this.navElement.style.top = null;
    }
  }

  updateCountdown(now) {
    const diff = this.targetDate - now
    if (diff < 0) return

    const twoHoursInMillis = 2 * 60 * 60 * 1000;

    const days = Math.floor(diff / (1000 * 60 * 60 * 24))
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60))
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))
    const seconds = Math.floor((diff % (1000 * 60)) / 1000)

    let countdownText = "Live in "
    if (days > 0) countdownText += `${days}d `
    if (hours > 0 || days > 0) countdownText += `${hours}h `
    if (minutes > 0 || hours > 0 || days > 0) countdownText += `${minutes}m `
    
    if (diff < twoHoursInMillis) { 
      if (countdownText === "Live in " || seconds >= 0) {
          countdownText += `${seconds}s`
      }      
    }

    try {
      this.statusTarget.textContent = countdownText
    } catch (e) {
      // console.error("Error setting statusTarget text:", e); // Can remove this now
    }
  }
}