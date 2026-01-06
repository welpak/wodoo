/** @odoo-module **/

import { registry } from "@web/core/registry";
import { _t } from "@web/core/l10n/translation";
import { PrintDialog } from "./print_modal";

async function printModalReportHandler(action, options, env) {
    // If the printer selection has already been made, let the action proceed normally.
    if (options && options.printer_selection_made) {
        return false;
    }

    // If it's not a report action, ignore.
    if (action.type !== 'ir.actions.report') {
        return false;
    }

    // Intercept: Show Dialog
    return new Promise((resolve) => {
        env.services.dialog.add(PrintDialog, {
            title: _t("Print Options"),
            confirm: async (result) => {
                const { printerId, copies } = result;

                // Clone options and add our flags
                const newOptions = { ...options, printer_selection_made: true };

                // Clone action and inject context
                const newContext = { ...action.context,
                    force_printer_id: printerId,
                    copies: copies,
                    // If printerId is 'client', we force client, else we force printer logic
                    force_print_to_client: printerId === 'client',
                };

                const newAction = { ...action, context: newContext };

                // Re-trigger the action
                await env.services.action.doAction(newAction, newOptions);
                // Return true to stop the current action propagation (avoid double print)
                resolve(true);
            },
            close: () => {
                // User cancelled, return true to stop propagation (prevent default print)
                resolve(true);
            }
        });
    });
}

// Register before standard handlers
registry.category("ir.actions.report handlers").add("print_modal_handler", printModalReportHandler, { sequence: 1 });
