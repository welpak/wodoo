/** @odoo-module **/

import { Component, useState, onWillStart } from "@odoo/owl";
import { Dialog } from "@web/core/dialog/dialog";
import { useService } from "@web/core/utils/hooks";
import { _t } from "@web/core/l10n/translation";
import { session } from "@web/session";

export class PrintDialog extends Component {
    setup() {
        this.orm = useService("orm");
        this.user = useService("user");
        this.state = useState({
            printers: [],
            selectedPrinterId: "client", // Default to download
            copies: 1,
        });

        onWillStart(async () => {
            await this.loadPrinters();
        });
    }

    async loadPrinters() {
        try {
            // Fetch printers
            const printers = await this.orm.searchRead("printing.printer", [], ["name"]);
            this.state.printers = printers;

            // Fetch user's default printer
            // We use session.uid to get the current user
            const userSettings = await this.orm.read("res.users", [session.uid], ["printing_printer_id"]);

            if (userSettings && userSettings.length > 0 && userSettings[0].printing_printer_id) {
                const defaultPrinterId = userSettings[0].printing_printer_id[0];
                // Verify the default printer is in the list we just fetched (it should be)
                if (printers.some(p => p.id === defaultPrinterId)) {
                    this.state.selectedPrinterId = defaultPrinterId;
                }
            }
        } catch (e) {
            console.error("Error fetching printers or user settings", e);
        }
    }

    _onConfirm() {
        this.props.confirm({
            printerId: this.state.selectedPrinterId,
            copies: this.state.copies,
        });
        this.props.close();
    }

    _onCancel() {
        this.props.close();
    }
}

PrintDialog.template = "print_modal.PrintDialog";
PrintDialog.components = { Dialog };
PrintDialog.props = {
    confirm: { type: Function },
    close: { type: Function },
    title: { type: String, optional: true },
};
