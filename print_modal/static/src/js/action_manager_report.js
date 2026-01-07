/** @odoo-module **/

import { registry } from "@web/core/registry";
import { _t } from "@web/core/l10n/translation";
import { PrintDialog } from "./print_modal";
import { evaluateExpr } from "@web/core/py_js/py";

async function printModalReportHandler(action, options, env) {
    // If the printer selection has already been made, execute the print logic directly
    // to ensure our context (with force_printer_id) is preserved.
    // The default OCA handler strips context, which breaks our forcing logic.
    if (options && options.printer_selection_made) {
        const context = action.context || {};

        // If we are forcing to client (Download), we can let the standard flow handle it.
        // Returning false allows the next handler (likely standard Odoo) to pick it up.
        // OCA handler will also run but will ignore 'client' action.
        if (context.force_print_to_client) {
             return false;
        }

        // If we have a forced printer, we must handle the server communication ourselves.
        try {
            const orm = env.services.orm;

            // 1. Check behaviour (this will trigger our backend override)
            const print_action = await orm.call(
                "ir.actions.report",
                "print_action_for_report_name",
                [action.report_name],
                { context: context }
            );

            // 2. If action is server, perform the print
            if (print_action && print_action.action === "server") {
                 // Using active_ids from context is standard for reports
                 const recordIds = context.active_ids || [];

                 const result = await orm.call(
                    "ir.actions.report",
                    "print_document_client_action",
                    [action.id, recordIds, action.data],
                    { context: context }
                );

                if (result) {
                    env.services.notification.add(_t("Successfully sent to printer!"), {
                        type: "success",
                    });
                } else {
                    // If result is empty/false, it means printing failed (raised exception or returned None)
                    env.services.notification.add(_t("Could not send to printer!"), {
                        type: "danger",
                    });

                    // We could optionally show the "Issue on..." dialog here if we wanted to match OCA perfectly,
                    // but a simple notification is often clearer.
                    // To be safe and avoid "Issue on false", we stick to the notification.
                }
                return true; // Stop propagation, we handled it.
            }
        } catch (e) {
            console.error("Print Modal: Error during custom print execution", e);
            env.services.notification.add(_t("Error communicating with printer server."), {
                type: "danger",
            });
            return true;
        }

        return false; // Fallback if action is not server or something else
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
                // Return true to stop the current action propagation
                resolve(true);
            },
            close: () => {
                resolve(true);
            }
        });
    });
}

// Register before standard handlers and OCA handlers
registry.category("ir.actions.report handlers").add("print_modal_handler", printModalReportHandler, { sequence: 1 });
