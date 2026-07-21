#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
 Eein Drive Service Configuration
 Version: 1.0.0
 Description: Python implementation of Eein Drive service configuration
=============================================================================
"""

from dataclasses import dataclass, field
from typing import List, Dict, Optional
from datetime import datetime


# ─────────────────────────────────────────────
# Data Classes for Service Configuration
# ─────────────────────────────────────────────

@dataclass
class ServiceInfo:
    """Service metadata"""
    name: str = "Eein Drive"
    version: str = "1.0.0"
    base_url: str = "https://drive.eein.com"
    status: str = "active"


@dataclass
class MediaAction:
    """Media playback action"""
    action: str
    type: str
    source: str
    status: str = "playing"
    response: str = "now"


@dataclass
class MediaConfig:
    """Media configuration for photo and video playback"""
    play_photo: MediaAction = field(default_factory=lambda: MediaAction(
        action="play",
        type="photo",
        source="SD Card"
    ))
    play_video_local: MediaAction = field(default_factory=lambda: MediaAction(
        action="play",
        type="video",
        source="Local Files"
    ))
    play_video_cloud: MediaAction = field(default_factory=lambda: MediaAction(
        action="play",
        type="video",
        source="Cloud Storage"
    ))


@dataclass
class Destination:
    """File sharing destination"""
    service: str
    location: str
    url: str


@dataclass
class FileShareInfo:
    """File sharing configuration"""
    types: List[str] = field(default_factory=lambda: ["PDF", "DOC", "PPT", "TXT", "XLS", "FILE"])
    count: int = 5
    destination: Optional[Destination] = None


@dataclass
class SpecificFile:
    """Specific file information"""
    name: str
    type: str
    size: str
    destination: Destination
    status: str = "ok"
    response: str = "now"


@dataclass
class ShareResult:
    """Share operation result"""
    status: str = "ok"
    message: str = "5 files uploaded"
    timestamp: str = "now"


@dataclass
class SharingConfig:
    """File sharing configuration"""
    action: str = "Share"
    files: FileShareInfo = field(default_factory=FileShareInfo)
    specific_file: Optional[SpecificFile] = None
    result: ShareResult = field(default_factory=ShareResult)


@dataclass
class AddressInfo:
    """Address configuration"""
    type: str
    address: str
    status: str = "active"
    response: str = "now"


@dataclass
class AddressesConfig:
    """All address types"""
    url: AddressInfo = field(default_factory=lambda: AddressInfo(
        type="url",
        address="https://drive.eein.com/Dededt"
    ))
    voice: AddressInfo = field(default_factory=lambda: AddressInfo(
        type="voice",
        address="voice://eein/Dededt"
    ))
    local_directory: AddressInfo = field(default_factory=lambda: AddressInfo(
        type="local_directory",
        address="ld://eein/Dededt"
    ))


@dataclass
class FormatInfo:
    """File format information"""
    description: str
    status: str = "supported"


@dataclass
class SupportedFormats:
    """Supported file formats"""
    formats: Dict[str, FormatInfo] = field(default_factory=lambda: {
        "PDF": FormatInfo("Portable Document Format"),
        "DOC": FormatInfo("Microsoft Word Document"),
        "PPT": FormatInfo("PowerPoint Presentation"),
        "TXT": FormatInfo("Plain Text File"),
        "XLS": FormatInfo("Microsoft Excel Spreadsheet"),
        "FILE": FormatInfo("Generic File")
    })


@dataclass
class ResponseCodes:
    """Response code definitions"""
    ok: str = "Operation completed successfully"
    now: str = "Immediate response"
    playing: str = "Media is currently playing"
    active: str = "Address/Service is active"


@dataclass
class ApiEndpoints:
    """API endpoint definitions"""
    play_photo: str = "GET /api/play/photo"
    play_video: str = "GET /api/play/video"
    share_files: str = "POST /api/share"
    get_url: str = "GET /api/address/url"
    get_voice: str = "GET /api/address/voice"
    get_local_dir: str = "GET /api/address/ld"


# ─────────────────────────────────────────────
# Main Service Class
# ─────────────────────────────────────────────

@dataclass
class EeinDriveService:
    """Main Eein Drive service configuration"""
    service: ServiceInfo = field(default_factory=ServiceInfo)
    media: MediaConfig = field(default_factory=MediaConfig)
    sharing: SharingConfig = field(default_factory=SharingConfig)
    addresses: AddressesConfig = field(default_factory=AddressesConfig)
    supported_formats: SupportedFormats = field(default_factory=SupportedFormats)
    response_codes: ResponseCodes = field(default_factory=ResponseCodes)
    api_endpoints: ApiEndpoints = field(default_factory=ApiEndpoints)
    
    def get_base_url(self) -> str:
        """Get service base URL"""
        return self.service.base_url
    
    def get_share_url(self) -> str:
        """Get file sharing URL"""
        if self.sharing.files.destination:
            return self.sharing.files.destination.url
        return ""
    
    def is_format_supported(self, file_type: str) -> bool:
        """Check if file format is supported"""
        return file_type.upper() in self.supported_formats.formats
    
    def get_api_endpoint(self, action: str) -> str:
        """Get API endpoint for specific action"""
        endpoints = {
            "play_photo": self.api_endpoints.play_photo,
            "play_video": self.api_endpoints.play_video,
            "share": self.api_endpoints.share_files,
            "url": self.api_endpoints.get_url,
            "voice": self.api_endpoints.get_voice,
            "local_dir": self.api_endpoints.get_local_dir
        }
        return endpoints.get(action, "")


# ─────────────────────────────────────────────
# Utility Functions
# ─────────────────────────────────────────────

def create_eein_drive_service() -> EeinDriveService:
    """Create and initialize Eein Drive service with default configuration"""
    
    # Create destination for file sharing
    destination = Destination(
        service="Eein Drive",
        location="drive://eein/root/",
        url="https://drive.eein.com/Dededt"
    )
    
    # Create specific file info
    specific_file = SpecificFile(
        name="finance.xls",
        type="XLS",
        size="2.4 MB",
        destination=destination
    )
    
    # Create file share info
    files_info = FileShareInfo(
        types=["PDF", "DOC", "PPT", "TXT", "XLS", "FILE"],
        count=5,
        destination=destination
    )
    
    # Create sharing config
    sharing_config = SharingConfig(
        action="Share",
        files=files_info,
        specific_file=specific_file,
        result=ShareResult(
            status="ok",
            message="5 files uploaded",
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        )
    )
    
    # Create main service
    service = EeinDriveService(
        sharing=sharing_config
    )
    
    return service


def print_service_info(service: EeinDriveService) -> None:
    """Print service configuration information"""
    print("=" * 70)
    print("EEIN DRIVE SERVICE CONFIGURATION")
    print("=" * 70)
    print(f"\nService Name: {service.service.name}")
    print(f"Version: {service.service.version}")
    print(f"Base URL: {service.service.base_url}")
    print(f"Status: {service.service.status}")
    
    print("\n" + "-" * 70)
    print("MEDIA CONFIGURATION")
    print("-" * 70)
    print(f"Photo Source: {service.media.play_photo.source}")
    print(f"Video Local Source: {service.media.play_video_local.source}")
    print(f"Video Cloud Source: {service.media.play_video_cloud.source}")
    
    print("\n" + "-" * 70)
    print("SHARING CONFIGURATION")
    print("-" * 70)
    print(f"Action: {service.sharing.action}")
    print(f"File Types: {', '.join(service.sharing.files.types)}")
    print(f"File Count: {service.sharing.files.count}")
    if service.sharing.files.destination:
        print(f"Destination URL: {service.sharing.files.destination.url}")
    
    if service.sharing.specific_file:
        print(f"\nSpecific File: {service.sharing.specific_file.name}")
        print(f"  Type: {service.sharing.specific_file.type}")
        print(f"  Size: {service.sharing.specific_file.size}")
    
    print(f"\nShare Result: {service.sharing.result.message}")
    
    print("\n" + "-" * 70)
    print("ADDRESSES")
    print("-" * 70)
    print(f"URL: {service.addresses.url.address}")
    print(f"Voice: {service.addresses.voice.address}")
    print(f"Local Directory: {service.addresses.local_directory.address}")
    
    print("\n" + "-" * 70)
    print("SUPPORTED FORMATS")
    print("-" * 70)
    for fmt, info in service.supported_formats.formats.items():
        print(f"  {fmt}: {info.description}")
    
    print("\n" + "-" * 70)
    print("API ENDPOINTS")
    print("-" * 70)
    print(f"Play Photo: {service.api_endpoints.play_photo}")
    print(f"Play Video: {service.api_endpoints.play_video}")
    print(f"Share Files: {service.api_endpoints.share_files}")
    print(f"Get URL: {service.api_endpoints.get_url}")
    print(f"Get Voice: {service.api_endpoints.get_voice}")
    print(f"Get Local Dir: {service.api_endpoints.get_local_dir}")
    
    print("\n" + "=" * 70)


# ─────────────────────────────────────────────
# Main Execution
# ─────────────────────────────────────────────

def main() -> None:
    """Main program execution"""
    print("\nInitializing Eein Drive Service...\n")
    
    # Create service instance
    service = create_eein_drive_service()
    
    # Print configuration
    print_service_info(service)
    
    # Example usage
    print("\n" + "=" * 70)
    print("EXAMPLE USAGE")
    print("=" * 70)
    
    # Check if format is supported
    test_formats = ["PDF", "MP4", "XLS", "EXE"]
    print("\nFormat Support Check:")
    for fmt in test_formats:
        is_supported = service.is_format_supported(fmt)
        status = "✓ Supported" if is_supported else "✗ Not Supported"
        print(f"  {fmt}: {status}")
    
    # Get API endpoints
    print("\nAPI Endpoints:")
    print(f"  Share API: {service.get_api_endpoint('share')}")
    print(f"  Play Video API: {service.get_api_endpoint('play_video')}")
    
    # Get URLs
    print(f"\nService URLs:")
    print(f"  Base URL: {service.get_base_url()}")
    print(f"  Share URL: {service.get_share_url()}")
    
    print("\n" + "=" * 70)
    print("Service initialized successfully!")
    print("=" * 70 + "\n")


if __name__ == "__main__":
    main()
