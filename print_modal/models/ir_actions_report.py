from odoo import models, api

class IrActionsReport(models.Model):
    _inherit = "ir.actions.report"

    def behaviour(self):
        """Override behaviour to respect forced printer and copies from context."""
        result = super().behaviour()
        context = self.env.context

        # Check for forced printer in context
        if context.get('force_printer_id'):
            printer_id = context.get('force_printer_id')
            if printer_id == 'client':
                 result['action'] = 'client'
                 # Remove printer if we force client
                 result.pop('printer', None)
            else:
                # Ensure printer_id is an integer
                try:
                    printer_id = int(printer_id)
                    printer = self.env['printing.printer'].browse(printer_id)
                    if printer.exists():
                        result['printer'] = printer
                        result['action'] = 'server'
                except (ValueError, TypeError):
                    pass

        # Check for copies in context
        if context.get('copies'):
            try:
                result['copies'] = int(context.get('copies'))
            except (ValueError, TypeError):
                pass

        return result
