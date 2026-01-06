/** @odoo-module **/

import { registry } from "@web/core/registry";
import { _t } from "@web/core/l10n/translation";
import { PrintDialog } from "./print_modal";
import { evaluateExpr } from "@web/core/py_js/py";

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

                // Ensure context is an object
                let baseContext = action.context || {};
                if (typeof baseContext === 'string') {
                    try {
                        baseContext = evaluateExpr(baseContext);
                    } catch (e) {
                        console.warn("Print Modal: Could not evaluate context string", baseContext);
                        baseContext = {};
                    }
                }

                // Prepare new context values
                // Ensure printerId is passed correctly (int or 'client')
                // If printerId is 'client', we don't force a printer ID.
                const forcePrinterId = printerId === 'client' ? false : parseInt(printerId);
                const numCopies = parseInt(copies) || 1;

                const newContext = {
                    ...baseContext,
                    force_printer_id: forcePrinterId,
                    copies: numCopies,
                    force_print_to_client: printerId === 'client',
                };

                const newAction = { ...action, context: newContext };

                console.log("Print Modal: Executing action with context:", newContext);

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
