/** @odoo-module **/

import { Component, useState, onWillStart } from "@odoo/owl";
import { Dialog } from "@web/core/dialog/dialog";
import { useService } from "@web/core/utils/hooks";
import { _t } from "@web/core/l10n/translation";

export class PrintDialog extends Component {
    setup() {
        this.orm = useService("orm");
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
            const printers = await this.orm.searchRead("printing.printer", [], ["name"]);
            this.state.printers = printers;
        } catch (e) {
            console.error("Error fetching printers", e);
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
