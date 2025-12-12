import httpx
import uuid
import logging
from typing import Optional, Any, Dict, List, Union
from src.config import settings

logger = logging.getLogger(__name__)

class OCSAPIError(Exception):
    def __init__(self, status_code: int, message: str, details: Optional[Dict[str, Any]] = None):
        self.status_code = status_code
        self.message = message
        self.details = details
        super().__init__(f"OCS API Error {status_code}: {message}")

class OCSClient:
    def __init__(self):
        self.base_url = settings.ocs_api_base_url
        self.api_key = settings.ocs_api_key
        self.timeout = settings.ocs_api_timeout
        self.client = httpx.AsyncClient(
            base_url=self.base_url,
            timeout=self.timeout,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": self.api_key,
                "Accept": "application/json",
            }
        )

    async def request(
        self, 
        method: str, 
        endpoint: str, 
        transaction_id: Optional[str] = None, 
        **kwargs
    ) -> Union[Dict[str, Any], List[Any], None]:
        if not transaction_id:
            transaction_id = str(uuid.uuid4())
        
        headers = kwargs.pop("headers", {})
        headers["X-Transaction-ID"] = transaction_id
        
        logger.debug(f"Making {method} request to {endpoint} with tx_id={transaction_id}")
        if "json" in kwargs:
            logger.debug(f"Request Body: {kwargs['json']}")

        try:
            response = await self.client.request(method, endpoint, headers=headers, **kwargs)
            
            if response.status_code >= 400:
                try:
                    error_body = response.json()
                    logger.error(f"Error Response Body: {error_body}")
                    message = error_body.get("message", response.reason_phrase)
                    details = error_body.get("details")
                except Exception:
                    message = response.text or response.reason_phrase
                    logger.error(f"Error Response Text: {message}")
                    details = None
                
                logger.error(f"OCS API Error: {response.status_code} - {message}")
                raise OCSAPIError(response.status_code, message, details)
            
            if response.status_code == 204:
                logger.debug("Response: 204 No Content")
                return None
            
            response_data = response.json()
            logger.debug(f"Response Body: {response_data}")
            return response_data
            
        except httpx.RequestError as e:
            logger.error(f"Network error accessing OCS API: {str(e)}")
            raise OCSAPIError(503, f"Service Unavailable: {str(e)}")
        except Exception as e:
            if isinstance(e, OCSAPIError):
                raise
            logger.error(f"Unexpected error: {str(e)}")
            raise OCSAPIError(500, f"Internal Client Error: {str(e)}")

    async def get(self, endpoint: str, transaction_id: Optional[str] = None, params: Optional[Dict] = None) -> Any:
        return await self.request("GET", endpoint, transaction_id, params=params)

    async def post(self, endpoint: str, transaction_id: Optional[str] = None, json: Optional[Dict] = None) -> Any:
        return await self.request("POST", endpoint, transaction_id, json=json)

    async def put(self, endpoint: str, transaction_id: Optional[str] = None, json: Optional[Dict] = None) -> Any:
        return await self.request("PUT", endpoint, transaction_id, json=json)

    async def patch(self, endpoint: str, transaction_id: Optional[str] = None, json: Optional[Any] = None) -> Any:
        return await self.request("PATCH", endpoint, transaction_id, json=json)

    async def delete(self, endpoint: str, transaction_id: Optional[str] = None) -> Any:
        return await self.request("DELETE", endpoint, transaction_id)

    async def close(self):
        await self.client.aclose()

# Global client instance
ocs_client = OCSClient()
