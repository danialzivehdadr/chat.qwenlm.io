#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
 Advanced Malware Scanner & Cleanup Tool
 Version: 1.0.0
 License: MIT License
 Description: Scans for infected files, quarantines threats, and frees up space
=============================================================================
"""

import os
import sys
import shutil
import hashlib
import json
import logging
import subprocess
import time
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Set, Optional, Tuple

# ─────────────────────────────────────────────
# Logging Configuration
# ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)-8s | %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────
# Malware Scanner Class
# ─────────────────────────────────────────────
class MalwareScanner:
    """
    Advanced malware scanner that identifies infected files based on:
    1. SHA-256 hash comparison with known malware database
    2. Suspicious file patterns (double extensions, hidden files)
    3. Anomalous file locations
    """
    
    # Suspicious file extensions that often indicate malware
    SUSPICIOUS_EXTENSIONS = {
        '.exe', '.bat', '.cmd', '.scr', '.pif', '.vbs', '.vbe', 
        '.js', '.jse', '.wsf', '.wsh', '.ps1', '.msi', '.dll'
    }
    
    # Double extension patterns (common malware technique)
    DOUBLE_EXTENSION_PATTERNS = [
        '.pdf.exe', '.doc.exe', '.jpg.exe', '.mp4.exe',
        '.txt.exe', '.zip.exe', '.rar.exe', '.avi.exe'
    ]
    
    # Protected system paths (never scan or modify)
    PROTECTED_PATHS = [
        '/system', '/recovery', '/dev', '/proc', '/sys',
        'Windows/System32', 'Windows/WinSxS'
    ]
    
    def __init__(self, quarantine_dir: str = "quarantine") -> None:
        """
        Initialize the malware scanner.
        
        Args:
            quarantine_dir: Directory to store quarantined files
        """
        self.quarantine_dir = Path(quarantine_dir).resolve()
        self.quarantine_dir.mkdir(exist_ok=True)
        
        self.malware_hashes: Set[str] = set()
        self.scan_results: List[Dict] = []
        self.total_freed_space = 0
        
        logger.info(f"MalwareScanner initialized | Quarantine: {self.quarantine_dir}")
    
    # ─────────────────────────────────────────
    # Malware Database Management
    # ─────────────────────────────────────────
    def load_malware_database(self, db_path: str = "malware_hashes.json") -> None:
        """
        Load known malware hashes from JSON database.
        
        Args:
            db_path: Path to malware hash database
        """
        if not os.path.exists(db_path):
            logger.warning(f"Malware database not found: {db_path}")
            logger.info("Creating empty malware database...")
            self._create_sample_database(db_path)
            return
        
        try:
            with open(db_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                self.malware_hashes = set(data.get('malware_hashes', []))
                logger.info(f"Loaded {len(self.malware_hashes)} malware hashes")
        except Exception as e:
            logger.error(f"Error loading malware database: {e}")
    
    def _create_sample_database(self, db_path: str) -> None:
        """Create a sample malware database with common test hashes."""
        sample_data = {
            "description": "Malware hash database - Add known malware SHA-256 hashes here",
            "last_updated": datetime.now().isoformat(),
            "malware_hashes": [
                # Add known malware SHA-256 hashes here
                # Example: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
            ]
        }
        
        with open(db_path, 'w', encoding='utf-8') as f:
            json.dump(sample_data, f, indent=2)
    
    # ─────────────────────────────────────────
    # File Hashing
    # ─────────────────────────────────────────
    @staticmethod
    def calculate_file_hash(file_path: str, algorithm: str = 'sha256') -> str:
        """
        Calculate hash of a file.
        
        Args:
            file_path: Path to file
            algorithm: Hash algorithm (sha256, md5, sha1)
        
        Returns:
            str: Hexadecimal hash string
        """
        hash_func = hashlib.new(algorithm)
        
        try:
            with open(file_path, 'rb') as f:
                for chunk in iter(lambda: f.read(8192), b''):
                    hash_func.update(chunk)
            return hash_func.hexdigest()
        except (OSError, PermissionError) as e:
            logger.debug(f"Cannot hash {file_path}: {e}")
            return ""
    
    # ─────────────────────────────────────────
    # Threat Detection
    # ─────────────────────────────────────────
    def is_file_suspicious(self, file_path: Path) -> Tuple[bool, str]:
        """
        Check if file matches suspicious patterns.
        
        Args:
            file_path: Path to file
        
        Returns:
            Tuple[bool, str]: (is_suspicious, reason)
        """
        file_name = file_path.name.lower()
        
        # Check for double extensions
        for pattern in self.DOUBLE_EXTENSION_PATTERNS:
            if file_name.endswith(pattern):
                return True, f"Double extension detected: {pattern}"
        
        # Check for hidden files with executable extensions
        if file_name.startswith('.') and file_path.suffix.lower() in self.SUSPICIOUS_EXTENSIONS:
            return True, "Hidden executable file"
        
        # Check for suspicious locations
        suspicious_dirs = ['temp', 'tmp', 'appdata', 'downloads']
        if any(susp_dir in str(file_path).lower() for susp_dir in suspicious_dirs):
            if file_path.suffix.lower() in self.SUSPICIOUS_EXTENSIONS:
                return True, "Executable in suspicious location"
        
        return False, ""
    
    def is_path_protected(self, path: Path) -> bool:
        """Check if path is in protected system directories."""
        path_str = str(path).lower()
        return any(protected in path_str for protected in self.PROTECTED_PATHS)
    
    # ─────────────────────────────────────────
    # Scanning
    # ─────────────────────────────────────────
    def scan_directory(self, directory: str, recursive: bool = True) -> List[Dict]:
        """
        Scan directory for malware and suspicious files.
        
        Args:
            directory: Directory to scan
            recursive: Whether to scan subdirectories
        
        Returns:
            List[Dict]: List of detected threats
        """
        scan_path = Path(directory).resolve()
        
        if not scan_path.exists():
            logger.error(f"Directory not found: {scan_path}")
            return []
        
        if self.is_path_protected(scan_path):
            logger.warning(f"Cannot scan protected path: {scan_path}")
            return []
        
        logger.info(f"Starting scan: {scan_path}")
        threats = []
        files_scanned = 0
        
        # Determine iteration method
        if recursive:
            file_iterator = scan_path.rglob('*')
        else:
            file_iterator = scan_path.glob('*')
        
        for file_path in file_iterator:
            if not file_path.is_file():
                continue
            
            files_scanned += 1
            
            # Skip protected paths
            if self.is_path_protected(file_path):
                continue
            
            threat_info = {
                "path": str(file_path),
                "size": 0,
                "hash": "",
                "threat_type": "",
                "reason": ""
            }
            
            try:
                threat_info["size"] = file_path.stat().st_size
                
                # Check suspicious patterns
                is_suspicious, reason = self.is_file_suspicious(file_path)
                if is_suspicious:
                    threat_info["threat_type"] = "SUSPICIOUS_PATTERN"
                    threat_info["reason"] = reason
                    threats.append(threat_info)
                    logger.warning(f"[SUSPICIOUS] {file_path.name} | {reason}")
                    continue
                
                # Check hash against malware database
                file_hash = self.calculate_file_hash(str(file_path))
                if file_hash:
                    threat_info["hash"] = file_hash
                    
                    if file_hash in self.malware_hashes:
                        threat_info["threat_type"] = "KNOWN_MALWARE"
                        threat_info["reason"] = "Matches known malware hash"
                        threats.append(threat_info)
                        logger.critical(f"[MALWARE] {file_path.name} | Hash: {file_hash[:16]}...")
                
            except (OSError, PermissionError) as e:
                logger.debug(f"Cannot scan {file_path}: {e}")
        
        logger.info(f"Scan completed | Files scanned: {files_scanned} | Threats found: {len(threats)}")
        return threats
    
    # ─────────────────────────────────────────
    # Quarantine & Cleanup
    # ─────────────────────────────────────────
    def quarantine_threats(self, threats: List[Dict]) -> Dict[str, int]:
        """
        Move detected threats to quarantine directory.
        
        Args:
            threats: List of detected threats
        
        Returns:
            Dict: Cleanup statistics
        """
        if not threats:
            logger.info("No threats to quarantine")
            return {"quarantined": 0, "failed": 0, "freed_bytes": 0}
        
        logger.info(f"Quarantining {len(threats)} threats...")
        
        stats = {"quarantined": 0, "failed": 0, "freed_bytes": 0}
        
        for i, threat in enumerate(threats):
            file_path = Path(threat["path"])
            
            if not file_path.exists():
                continue
            
            try:
                # Create unique quarantine filename
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                quarantine_name = f"{timestamp}_{file_path.name}"
                quarantine_path = self.quarantine_dir / quarantine_name
                
                # Move file to quarantine
                shutil.move(str(file_path), str(quarantine_path))
                
                stats["quarantined"] += 1
                stats["freed_bytes"] += threat["size"]
                
                logger.info(f"[QUARANTINED] {file_path.name} -> {quarantine_path.name}")
                
                # Batch sync every 10 files
                if (i + 1) % 10 == 0:
                    self._flush_storage_cache()
                
            except Exception as e:
                stats["failed"] += 1
                logger.error(f"Failed to quarantine {file_path.name}: {e}")
        
        # Final sync
        self._flush_storage_cache()
        
        return stats
    
    @staticmethod
    def _flush_storage_cache() -> None:
        """Flush filesystem cache to prevent storage corruption."""
        try:
            os.sync()
            subprocess.run(['sync'], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
    
    # ─────────────────────────────────────────
    # Reporting
    # ─────────────────────────────────────────
    def generate_report(self, stats: Dict[str, int]) -> str:
        """Generate comprehensive cleanup report."""
        report_lines = [
            "=" * 70,
            "MALWARE SCAN & CLEANUP REPORT",
            f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "=" * 70,
            "",
            "SCAN SUMMARY:",
            f"  Total threats detected: {len(self.scan_results)}",
            f"  Files quarantined: {stats['quarantined']}",
            f"  Failed operations: {stats['failed']}",
            f"  Space freed: {self._format_size(stats['freed_bytes'])}",
            "",
            "QUARANTINE LOCATION:",
            f"  {self.quarantine_dir}",
            "",
            "DETAILED THREAT LIST:",
            "-" * 70,
        ]
        
        for threat in self.scan_results:
            report_lines.append(f"  File: {threat['path']}")
            report_lines.append(f"  Type: {threat['threat_type']}")
            report_lines.append(f"  Reason: {threat['reason']}")
            if threat['hash']:
                report_lines.append(f"  Hash: {threat['hash']}")
            report_lines.append(f"  Size: {self._format_size(threat['size'])}")
            report_lines.append("-" * 70)
        
        report_lines.extend([
            "",
            "RECOMMENDATIONS:",
            "  1. Review quarantined files before permanent deletion",
            "  2. Update malware database regularly",
            "  3. Run scans periodically on high-risk directories",
            "  4. Keep system and applications updated",
            "",
            "=" * 70,
        ])
        
        return "\n".join(report_lines)
    
    @staticmethod
    def _format_size(size_bytes: int) -> str:
        """Convert bytes to human-readable format."""
        for unit in ['Bytes', 'KB', 'MB', 'GB', 'TB']:
            if size_bytes < 1024.0:
                return f"{size_bytes:.2f} {unit}"
            size_bytes /= 1024.0
        return f"{size_bytes:.2f} PB"


# ─────────────────────────────────────────────
# Main Execution
# ─────────────────────────────────────────────
def main() -> None:
    """Main program execution."""
    print("\n" + "=" * 70)
    print("  Advanced Malware Scanner & Cleanup Tool v1.0.0")
    print("  License: MIT | Author: danialzivehdar1992@gmail.com")
    print("=" * 70 + "\n")
    
    try:
        # Initialize scanner
        scanner = MalwareScanner(quarantine_dir="quarantine")
        
        # Load malware database
        scanner.load_malware_database("malware_hashes.json")
        
        # Scan target directory (customize as needed)
        target_dir = input("Enter directory to scan (or press Enter for current): ").strip()
        if not target_dir:
            target_dir = "."
        
        # Perform scan
        threats = scanner.scan_directory(target_dir, recursive=True)
        scanner.scan_results = threats
        
        if not threats:
            logger.info("No threats detected! System appears clean.")
            return
        
        # Quarantine threats
        stats = scanner.quarantine_threats(threats)
        
        # Generate and display report
        report = scanner.generate_report(stats)
        print("\n" + report)
        
        # Save report to file
        report_file = f"scan_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(report)
        
        logger.info(f"Report saved to: {report_file}")
        
    except KeyboardInterrupt:
        logger.warning("Scan cancelled by user")
        sys.exit(0)
    except Exception as e:
        logger.critical(f"Critical error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
