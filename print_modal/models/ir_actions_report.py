from odoo import models, api
import logging

_logger = logging.getLogger(__name__)

class IrActionsReport(models.Model):
    _inherit = "ir.actions.report"

    def behaviour(self):
        """Override behaviour to respect forced printer and copies from context."""
        context = self.env.context
        _logger.info(f"PRINT_MODAL: Starting behaviour override. Context: {context}")

        # Check for forced client (Download PDF) FIRST
        if context.get('force_print_to_client'):
            _logger.info("PRINT_MODAL: Forced to client.")
            # We strictly return client action, bypassing super() if possible or ignoring its result
            # But we must return a dict with 'action': 'client'
            return {'action': 'client', 'type': 'ir.actions.report'}

        result = super().behaviour()
        _logger.info(f"PRINT_MODAL: Result from super(): {result}")

        # Check for forced printer in context
        if context.get('force_printer_id'):
            printer_id = context.get('force_printer_id')
            _logger.info(f"PRINT_MODAL: Forcing printer_id: {printer_id}")

            try:
                printer_id = int(printer_id)
                printer = self.env['printing.printer'].browse(printer_id)
                if printer.exists():
                    result['printer'] = printer
                    result['action'] = 'server'
                    _logger.info(f"PRINT_MODAL: Printer set to {printer.name}")
                else:
                    _logger.warning(f"PRINT_MODAL: Printer {printer_id} does not exist.")
            except (ValueError, TypeError) as e:
                _logger.error(f"PRINT_MODAL: Error setting printer: {e}")

        # Check for copies in context
        if context.get('copies'):
            try:
                copies = int(context.get('copies'))
                result['copies'] = copies
                result['num-copies'] = copies # redundant key for safety
                _logger.info(f"PRINT_MODAL: Copies set to {copies}")
            except (ValueError, TypeError):
                pass

        _logger.info(f"PRINT_MODAL: Final result: {result}")
        return result
