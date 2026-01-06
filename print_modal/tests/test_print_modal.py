from odoo.tests.common import TransactionCase

class TestPrintModal(TransactionCase):
    def setUp(self):
        super(TestPrintModal, self).setUp()
        self.printer_model = self.env['printing.printer']
        self.report_model = self.env['ir.actions.report']

        # Create a dummy printer
        self.printer = self.printer_model.create({
            'name': 'Test Printer',
            'system_name': 'Test_Printer_Sys',
            'default': True,
            'status': 'available',
            'status_message': 'Ready',
            'model': 'Generic',
            'location': 'Office',
            'uri': 'ipp://localhost/printers/Test_Printer_Sys',
        })

        # Get a report (e.g., User Badge)
        self.report = self.env.ref('base.action_report_user')

    def test_behaviour_forced_printer(self):
        """Test that behaviour() respects force_printer_id"""
        ctx = {'force_printer_id': self.printer.id}
        report_with_context = self.report.with_context(ctx)

        behaviour = report_with_context.behaviour()

        self.assertEqual(behaviour.get('printer'), self.printer, "Should return the forced printer")
        self.assertEqual(behaviour.get('action'), 'server', "Action should be server")

    def test_behaviour_forced_client(self):
        """Test that behaviour() respects force_printer_id='client'"""
        ctx = {'force_printer_id': 'client'}
        report_with_context = self.report.with_context(ctx)

        behaviour = report_with_context.behaviour()

        self.assertIsNone(behaviour.get('printer'), "Should not have a printer")
        self.assertEqual(behaviour.get('action'), 'client', "Action should be client")

    def test_behaviour_copies(self):
        """Test that behaviour() passes copies"""
        ctx = {'copies': 5}
        report_with_context = self.report.with_context(ctx)

        behaviour = report_with_context.behaviour()

        self.assertEqual(behaviour.get('copies'), 5, "Should return correct copies")
