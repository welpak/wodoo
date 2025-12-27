// Wodoo - Alpine.js Application
const API_BASE = '/api/v1';

function app() {
    return {
        // State
        activeTab: 'move',
        loading: false,
        connected: false,
        connectionStatus: false,
        message: '',
        messageType: 'success',

        // Move Form
        moveForm: {
            productId: null,
            productName: '',
            productSearch: '',
            fromLocationId: null,
            fromLocationName: '',
            fromLocationSearch: '',
            toLocationId: null,
            toLocationName: '',
            toLocationSearch: '',
            quantity: 1,
            note: ''
        },
        productResults: [],
        fromLocationResults: [],
        toLocationResults: [],

        // Adjust Form
        adjustForm: {
            productId: null,
            productName: '',
            productSearch: '',
            locationId: null,
            locationName: '',
            locationSearch: '',
            quantity: 0,
            note: ''
        },
        adjustProductResults: [],
        adjustLocationResults: [],

        // Locations
        locations: [],
        locationSearchQuery: '',
        showAddLocationForm: false,
        newLocation: {
            name: '',
            barcode: '',
            usage: 'internal'
        },

        // Stock
        stockList: [],
        stockFilters: {
            productSearch: '',
            locationSearch: ''
        },

        // Search debounce timers
        searchTimeout: null,

        // Initialize
        async init() {
            await this.checkConnection();
            await this.loadLocations();
        },

        // API Methods
        async apiCall(endpoint, method = 'GET', data = null) {
            try {
                const options = {
                    method,
                    headers: {
                        'Content-Type': 'application/json',
                    }
                };

                if (data && (method === 'POST' || method === 'PUT')) {
                    options.body = JSON.stringify(data);
                }

                const response = await fetch(`${API_BASE}${endpoint}`, options);
                const result = await response.json();

                if (!response.ok) {
                    throw new Error(result.detail || 'API request failed');
                }

                return result;
            } catch (error) {
                console.error('API Error:', error);
                throw error;
            }
        },

        // Connection
        async checkConnection() {
            try {
                const result = await fetch('/api/test-connection');
                const data = await result.json();
                this.connected = data.success;
                this.connectionStatus = true;
            } catch (error) {
                this.connected = false;
                this.connectionStatus = true;
            }
        },

        // Product Search
        async searchProducts(query, isAdjust = false) {
            if (!query || query.length < 2) {
                if (isAdjust) {
                    this.adjustProductResults = [];
                } else {
                    this.productResults = [];
                }
                return;
            }

            clearTimeout(this.searchTimeout);
            this.searchTimeout = setTimeout(async () => {
                try {
                    const results = await this.apiCall(`/inventory/products?search=${encodeURIComponent(query)}&limit=10`);
                    if (isAdjust) {
                        this.adjustProductResults = results;
                    } else {
                        this.productResults = results;
                    }
                } catch (error) {
                    this.showMessage(`Error searching products: ${error.message}`, 'error');
                }
            }, 300);
        },

        selectProduct(product, isAdjust = false) {
            if (isAdjust) {
                this.adjustForm.productId = product.id;
                this.adjustForm.productName = product.name;
                this.adjustForm.productSearch = '';
                this.adjustProductResults = [];
            } else {
                this.moveForm.productId = product.id;
                this.moveForm.productName = product.name;
                this.moveForm.productSearch = '';
                this.productResults = [];
            }
        },

        selectFirstProduct(isAdjust = false) {
            const results = isAdjust ? this.adjustProductResults : this.productResults;
            if (results.length > 0) {
                this.selectProduct(results[0], isAdjust);
            }
        },

        // Location Search
        async searchLocations(query, type = 'from') {
            if (!query || query.length < 2) {
                this[`${type}LocationResults`] = [];
                return;
            }

            clearTimeout(this.searchTimeout);
            this.searchTimeout = setTimeout(async () => {
                try {
                    const results = await this.apiCall(`/locations/?search=${encodeURIComponent(query)}&limit=10`);
                    this[`${type}LocationResults`] = results;
                } catch (error) {
                    this.showMessage(`Error searching locations: ${error.message}`, 'error');
                }
            }, 300);
        },

        selectLocation(location, type = 'from') {
            if (type === 'from') {
                this.moveForm.fromLocationId = location.id;
                this.moveForm.fromLocationName = location.complete_name || location.name;
                this.moveForm.fromLocationSearch = '';
                this.fromLocationResults = [];
            } else if (type === 'to') {
                this.moveForm.toLocationId = location.id;
                this.moveForm.toLocationName = location.complete_name || location.name;
                this.moveForm.toLocationSearch = '';
                this.toLocationResults = [];
            } else if (type === 'adjust') {
                this.adjustForm.locationId = location.id;
                this.adjustForm.locationName = location.complete_name || location.name;
                this.adjustForm.locationSearch = '';
                this.adjustLocationResults = [];
            }
        },

        selectFirstLocation(type = 'from') {
            const results = this[`${type}LocationResults`];
            if (results.length > 0) {
                this.selectLocation(results[0], type);
            }
        },

        // Move Product
        async moveProduct() {
            if (!this.moveForm.productId || !this.moveForm.fromLocationId || !this.moveForm.toLocationId) {
                this.showMessage('Please select product and locations', 'error');
                return;
            }

            this.loading = true;
            try {
                const data = {
                    product_id: this.moveForm.productId,
                    from_location_id: this.moveForm.fromLocationId,
                    to_location_id: this.moveForm.toLocationId,
                    quantity: parseFloat(this.moveForm.quantity),
                    note: this.moveForm.note
                };

                const result = await this.apiCall('/inventory/move', 'POST', data);
                this.showMessage(result.message, 'success');
                this.resetMoveForm();
            } catch (error) {
                this.showMessage(`Error moving product: ${error.message}`, 'error');
            } finally {
                this.loading = false;
            }
        },

        resetMoveForm() {
            this.moveForm = {
                productId: null,
                productName: '',
                productSearch: '',
                fromLocationId: null,
                fromLocationName: '',
                fromLocationSearch: '',
                toLocationId: null,
                toLocationName: '',
                toLocationSearch: '',
                quantity: 1,
                note: ''
            };
            this.productResults = [];
            this.fromLocationResults = [];
            this.toLocationResults = [];
        },

        // Adjust Inventory
        async adjustInventory() {
            if (!this.adjustForm.productId || !this.adjustForm.locationId) {
                this.showMessage('Please select product and location', 'error');
                return;
            }

            this.loading = true;
            try {
                const data = {
                    product_id: this.adjustForm.productId,
                    location_id: this.adjustForm.locationId,
                    quantity: parseFloat(this.adjustForm.quantity),
                    note: this.adjustForm.note
                };

                const result = await this.apiCall('/inventory/adjust', 'POST', data);
                this.showMessage(result.message, 'success');
                this.resetAdjustForm();
            } catch (error) {
                this.showMessage(`Error adjusting inventory: ${error.message}`, 'error');
            } finally {
                this.loading = false;
            }
        },

        resetAdjustForm() {
            this.adjustForm = {
                productId: null,
                productName: '',
                productSearch: '',
                locationId: null,
                locationName: '',
                locationSearch: '',
                quantity: 0,
                note: ''
            };
            this.adjustProductResults = [];
            this.adjustLocationResults = [];
        },

        // Location Management
        async loadLocations() {
            try {
                const query = this.locationSearchQuery ? `?search=${encodeURIComponent(this.locationSearchQuery)}` : '';
                this.locations = await this.apiCall(`/locations/${query}`);
            } catch (error) {
                this.showMessage(`Error loading locations: ${error.message}`, 'error');
            }
        },

        async addLocation() {
            if (!this.newLocation.name) {
                this.showMessage('Location name is required', 'error');
                return;
            }

            this.loading = true;
            try {
                const result = await this.apiCall('/locations/', 'POST', this.newLocation);
                this.showMessage(result.message, 'success');
                this.newLocation = { name: '', barcode: '', usage: 'internal' };
                this.showAddLocationForm = false;
                await this.loadLocations();
            } catch (error) {
                this.showMessage(`Error adding location: ${error.message}`, 'error');
            } finally {
                this.loading = false;
            }
        },

        async deleteLocation(locationId) {
            if (!confirm('Are you sure you want to delete this location?')) {
                return;
            }

            this.loading = true;
            try {
                const result = await this.apiCall(`/locations/${locationId}`, 'DELETE');
                this.showMessage(result.message, 'success');
                await this.loadLocations();
            } catch (error) {
                this.showMessage(`Error deleting location: ${error.message}`, 'error');
            } finally {
                this.loading = false;
            }
        },

        async viewLocationStock(locationId) {
            this.activeTab = 'stock';
            try {
                this.stockList = await this.apiCall(`/inventory/stock/location/${locationId}`);
            } catch (error) {
                this.showMessage(`Error loading location stock: ${error.message}`, 'error');
            }
        },

        // Stock View
        async loadStock() {
            try {
                let query = '?limit=200';
                // Note: For full filtering, we'd need to resolve product/location IDs from search terms
                // For now, this shows all stock
                this.stockList = await this.apiCall(`/inventory/stock${query}`);
            } catch (error) {
                this.showMessage(`Error loading stock: ${error.message}`, 'error');
            }
        },

        // Messages
        showMessage(text, type = 'success') {
            this.message = text;
            this.messageType = type;
            setTimeout(() => {
                this.message = '';
            }, 5000);
        }
    };
}
