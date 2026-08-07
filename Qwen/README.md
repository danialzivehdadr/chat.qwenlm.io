import os
import shutil
import json
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Optional
import logging

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class TrashBinManager:
    """
    Trash bin management system for data repositories.
    Features include file restoration, automated cleanup, and storage management.
    """
    
    def __init__(self, repository_path: str, trash_path: str = None, 
                 auto_cleanup_days: int = 30):
        """
        Initialize the Trash Bin Manager.
        
        Args:
            repository_path: Path to the main repository.
            trash_path: Path to the trash bin (Default: '.trash' inside the repository).
            auto_cleanup_days: Number of days before automatic cleanup (Default: 30 days).
        """
        self.repository = Path(repository_path)
        self.trash = Path(trash_path) if trash_path else self.repository / '.trash'
        self.metadata_file = self.trash / 'trash_metadata.json'
        self.auto_cleanup_days = auto_cleanup_days
        
        # Create the trash directory if it does not exist
        self.trash.mkdir(parents=True, exist_ok=True)
        
        # Load metadata
        self.metadata = self._load_metadata()
        
        logging.info(f"Trash Bin initialized at: {self.trash}")
    
    def _load_metadata(self) -> Dict:
        """Load trash bin metadata from a JSON file."""
        if self.metadata_file.exists():
            try:
                with open(self.metadata_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                logging.error(f"Error loading metadata: {e}")
                return {}
        return {}
    
    def _save_metadata(self):
        """Save trash bin metadata to a JSON file."""
        try:
            with open(self.metadata_file, 'w', encoding='utf-8') as f:
                json.dump(self.metadata, f, indent=2, ensure_ascii=False)
        except Exception as e:
            logging.error(f"Error saving metadata: {e}")
    
    def move_to_trash(self, file_path: str) -> bool:
        """
        Move a file to the trash bin (Soft Delete).
        
        Args:
            file_path: Path of the file to be moved to the trash.
            
        Returns:
            bool: True if the operation was successful, False otherwise.
        """
        source = Path(file_path)
        
        if not source.exists():
            logging.error(f"File not found: {source}")
            return False
        
        # Generate a unique name to prevent conflicts
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        trash_filename = f"{source.name}_{timestamp}"
        destination = self.trash / trash_filename
        
        try:
            # Move the file to the trash bin
            shutil.move(str(source), str(destination))
            
            # Save metadata
            self.metadata[str(destination)] = {
                'original_path': str(source.absolute()),
                'original_name': source.name,
                'deleted_at': datetime.now().isoformat(),
                'size': destination.stat().st_size
            }
            self._save_metadata()
            
            logging.info(f"Moved to trash: {source.name}")
            return True
            
        except Exception as e:
            logging.error(f"Error moving file to trash: {e}")
            return False
    
    def restore_file(self, trash_filename: str) -> bool:
        """
        Restore a file from the trash bin.
        
        Args:
            trash_filename: Name of the file in the trash bin.
            
        Returns:
            bool: True if the operation was successful, False otherwise.
        """
        trash_file = self.trash / trash_filename
        
        if not trash_file.exists():
            logging.error(f"File not found in trash: {trash_filename}")
            return False
        
        if trash_filename not in self.metadata:
            logging.error(f"No metadata found for: {trash_filename}")
            return False
        
        original_path = Path(self.metadata[trash_filename]['original_path'])
        
        try:
            # Check if a file with the same name already exists at the original location
            if original_path.exists():
                logging.warning(f"File already exists at original location: {original_path}")
                # Create a new name with a '_restored' suffix
                original_path = original_path.with_name(
                    f"{original_path.stem}_restored{original_path.suffix}"
                )
            
            # Restore the file
            shutil.move(str(trash_file), str(original_path))
            
            # Remove from metadata
            del self.metadata[trash_filename]
            self._save_metadata()
            
            logging.info(f"Restored file to: {original_path}")
            return True
            
        except Exception as e:
            logging.error(f"Error restoring file: {e}")
            return False
    
    def permanent_delete(self, trash_filename: str) -> bool:
        """
        Permanently delete a file from the trash bin.
        
        Args:
            trash_filename: Name of the file in the trash bin.
            
        Returns:
            bool: True if the operation was successful, False otherwise.
        """
        trash_file = self.trash / trash_filename
        
        if not trash_file.exists():
            logging.error(f"File not found in trash: {trash_filename}")
            return False
        
        try:
            trash_file.unlink()
            
            if trash_filename in self.metadata:
                del self.metadata[trash_filename]
                self._save_metadata()
            
            logging.info(f"Permanently deleted: {trash_filename}")
            return True
            
        except Exception as e:
            logging.error(f"Error permanently deleting file: {e}")
            return False
    
    def auto_cleanup(self) -> int:
        """
        Automatically clean up files older than 'auto_cleanup_days'.
        
        Returns:
            int: Number of files deleted.
        """
        cutoff_date = datetime.now() - timedelta(days=self.auto_cleanup_days)
        deleted_count = 0
        
        files_to_delete = []
        
        for filename, data in self.metadata.items():
            deleted_at = datetime.fromisoformat(data['deleted_at'])
            if deleted_at < cutoff_date:
                files_to_delete.append(filename)
        
        for filename in files_to_delete:
            if self.permanent_delete(filename):
                deleted_count += 1
        
        logging.info(f"Auto-cleanup completed: {deleted_count} files deleted")
        return deleted_count
    
    def list_trash(self) -> List[Dict]:
        """
        List all files currently in the trash bin.
        
        Returns:
            List[Dict]: List of file information dictionaries.
        """
        trash_items = []
        
        for filename, data in self.metadata.items():
            trash_items.append({
                'filename': filename,
                'original_name': data['original_name'],
                'original_path': data['original_path'],
                'deleted_at': data['deleted_at'],
                'size_mb': round(data['size'] / (1024 * 1024), 2)
            })
        
        return trash_items
    
    def get_trash_size(self) -> float:
        """
        Calculate the total size of the trash bin (in Megabytes).
        
        Returns:
            float: Total size of the trash bin in MB.
        """
        total_size = sum(data['size'] for data in self.metadata.values())
        return round(total_size / (1024 * 1024), 2)
    
    def empty_trash(self) -> int:
        """
        Completely empty the trash bin.
        
        Returns:
            int: Number of files deleted.
        """
        deleted_count = len(self.metadata)
        
        for filename in list(self.metadata.keys()):
            self.permanent_delete(filename)
        
        logging.info(f"Trash emptied: {deleted_count} files deleted")
        return deleted_count


# Example usage of the class
if __name__ == "__main__":
    # Initialize the Trash Bin Manager
    trash_manager = TrashBinManager(
        repository_path="./my_repository",
        auto_cleanup_days=30
    )
    
    # Example 1: Move a file to the trash
    # trash_manager.move_to_trash("./my_repository/old_file.txt")
    
    # Example 2: List files in the trash
    trash_items = trash_manager.list_trash()
    print(f"Files in trash: {len(trash_items)}")
    print(f"Total size: {trash_manager.get_trash_size()} MB")
    
    # Example 3: Restore a specific file
    # trash_manager.restore_file("old_file.txt_20260714_120000")
    
    # Example 4: Run automated cleanup
    # trash_manager.auto_cleanup()
    
    # Example 5: Completely empty the trash
    # trash_manager.empty_trash()
