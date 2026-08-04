import pyautogui
import time

# A brief pause to prepare and navigate to the target screen
time.sleep(3)

try:
    # Searching for the delete button image on the screen (delete_button.png must be available)
    button_location = pyautogui.locateOnScreen('delete_button.png', confidence=0.8)
    
    if button_location:
        # Clicking on the center of the located button
        pyautogui.click(pyautogui.center(button_location))
        print("The operation to click the delete button was completed successfully.")
    else:
        print("The target button was not found on the screen.")
        
except Exception as e:
    print(f"An error occurred during the image recognition process: {e}")
