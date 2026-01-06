{
    'name': 'Print Modal',
    'version': '16.0.1.0.0',
    'category': 'Printing',
    'summary': 'Modal to select printer and copies before printing',
    'depends': ['web', 'base_report_to_printer'],
    'data': [
    ],
    'assets': {
        'web.assets_backend': [
            'print_modal/static/src/xml/print_modal.xml',
            'print_modal/static/src/js/print_modal.js',
            'print_modal/static/src/js/action_manager_report.js',
        ],
    },
    'license': 'AGPL-3',
}
