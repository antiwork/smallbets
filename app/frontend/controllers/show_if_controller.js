import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static values = { role: String, roles: Array, id: Number }

    connect() {
        this.#showOnRoleMatch()
        this.#showOnIdMatch()
    }
    
    #showOnRoleMatch() {
        const userRole = Current.user?.role?.trim()?.toLowerCase() ?? ""
        const allowedRoles = this.#allowedRoles()

        if (allowedRoles.length && allowedRoles.includes(userRole)) this.#show();
    }

    #showOnIdMatch() {
        if (this.hasIdValue && this.idValue === Current.user?.id) this.#show();
    }
    
    #show() {
        this.element.removeAttribute("hidden");
    }

    #allowedRoles() {
        if (this.hasRolesValue) {
            return this.rolesValue.map((r) => r.trim().toLowerCase())
        } else if (this.hasRoleValue) {
            return [this.roleValue.toLowerCase()]
        }
        return []
    }
}
