from odoo import models, api

class IrActionsReport(models.Model):
    _inherit = "ir.actions.report"

    def behaviour(self):
        """Override behaviour to respect forced printer and copies from context."""
        result = super().behaviour()
        context = self.env.context

        # Check for forced client (Download PDF)
        # We check this first to prioritize the user's explicit choice to download
        if context.get('force_print_to_client'):
            result['action'] = 'client'
            result.pop('printer', None)
            return result

        # Check for forced printer in context
        if context.get('force_printer_id'):
            printer_id = context.get('force_printer_id')
            # Ensure printer_id is an integer
            try:
                printer_id = int(printer_id)
                printer = self.env['printing.printer'].browse(printer_id)
                if printer.exists():
                    result['printer'] = printer
                    result['action'] = 'server'
            except (ValueError, TypeError):
                # If printer ID is invalid, we fall back to default behaviour (which usually prints to configured printer or downloads)
                pass

        # Check for copies in context
        # We inject copies into the result, assuming the printing module uses this result dict
        if context.get('copies'):
            try:
                copies = int(context.get('copies'))
                result['copies'] = copies
                # Also add num-copies for wider compatibility
                result['num-copies'] = copies
            except (ValueError, TypeError):
                pass

        return result
