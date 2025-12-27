"""Odoo XML-RPC Client for API interactions"""
import xmlrpc.client
from typing import Any, Optional
from functools import lru_cache
from .config import get_settings


class OdooClient:
    """Client for interacting with Odoo API via XML-RPC"""

    def __init__(self):
        self.settings = get_settings()
        self.url = self.settings.odoo_url
        self.db = self.settings.odoo_db
        self.username = self.settings.odoo_username
        self.password = self.settings.odoo_password
        self._uid: Optional[int] = None

        # XML-RPC endpoints
        self.common = xmlrpc.client.ServerProxy(f'{self.url}/xmlrpc/2/common')
        self.models = xmlrpc.client.ServerProxy(f'{self.url}/xmlrpc/2/object')

    @property
    def uid(self) -> int:
        """Get authenticated user ID (cached)"""
        if self._uid is None:
            self._uid = self.common.authenticate(
                self.db, self.username, self.password, {}
            )
        return self._uid

    def execute(self, model: str, method: str, *args, **kwargs) -> Any:
        """Execute a method on an Odoo model"""
        return self.models.execute_kw(
            self.db, self.uid, self.password,
            model, method, args, kwargs
        )

    def search(self, model: str, domain: list, limit: Optional[int] = None,
               offset: int = 0, order: str = 'id') -> list:
        """Search for records in a model"""
        kwargs = {'offset': offset, 'order': order}
        if limit:
            kwargs['limit'] = limit
        return self.execute(model, 'search', domain, kwargs)

    def read(self, model: str, ids: list, fields: Optional[list] = None) -> list:
        """Read records from a model"""
        kwargs = {}
        if fields:
            kwargs['fields'] = fields
        return self.execute(model, 'read', ids, kwargs)

    def search_read(self, model: str, domain: list, fields: Optional[list] = None,
                    limit: Optional[int] = None, offset: int = 0, order: str = 'id') -> list:
        """Search and read records in one call"""
        kwargs = {'offset': offset, 'order': order}
        if fields:
            kwargs['fields'] = fields
        if limit:
            kwargs['limit'] = limit
        return self.execute(model, 'search_read', domain, kwargs)

    def create(self, model: str, values: dict) -> int:
        """Create a new record"""
        return self.execute(model, 'create', values)

    def write(self, model: str, ids: list, values: dict) -> bool:
        """Update existing records"""
        return self.execute(model, 'write', ids, values)

    def unlink(self, model: str, ids: list) -> bool:
        """Delete records"""
        return self.execute(model, 'unlink', ids)

    def test_connection(self) -> dict:
        """Test the Odoo connection and return server version"""
        try:
            version = self.common.version()
            uid = self.uid
            return {
                "success": True,
                "version": version,
                "uid": uid,
                "message": "Successfully connected to Odoo"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": "Failed to connect to Odoo"
            }


@lru_cache()
def get_odoo_client() -> OdooClient:
    """Get cached Odoo client instance"""
    return OdooClient()
