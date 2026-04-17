import FreeSimpleGUI as sg
import sys

# Configuration
MIN_ROW = 2
MAX_ROW = 14 # Max row is actually one less than this value!
COLS = 8
INIT_CHAR_CODE = 32 # ASCII code for space character
MIN_CHAR_CODE = 32 # First 32 codes are non-printable characters
MAX_CHAR_CODE = 256 # Max code value is actually one less than this value!
EMPTY_FILE_STR = "File not selected"

def main():
    file_path = None
    file_data = b'\xFF' * 4096 # Initially 4-kilobytes of 0xFF values

    total_args = len(sys.argv)
    if total_args > 1:
        file_path = sys.argv[1]
        open(file_path) # Try to open the CharGen file passed as a parameter

    sg.theme('Dark Amber')

    menu_def = [
        ['&File', ['&New', '&Open...   Ctrl+O', '&Save       Ctrl+S', 'Save &as...', '---', 'E&xit']],
        ['&Edit', ['&Copy     Ctrl+C', '&Paste    Ctrl+V', '---', 'C&lear']],
        ['&View', 'View &font...'],
        ['&Help', '&About...'],
    ]

    # Create the grid of buttons and rest of the layout
    range_values = list(range(MIN_CHAR_CODE, MAX_CHAR_CODE))
    layout = [[sg.Menu(menu_def)],
              [sg.Text(text='Key code:', pad=(1, 5)), sg.Spin(values=range_values, initial_value=INIT_CHAR_CODE, size=(5, 1), key='-SPIN-', enable_events=True),
              sg.Text(text='hex: ' + hex(INIT_CHAR_CODE), key='-HEX-')]]

    row_no = 1
    for r in range(MIN_ROW, MAX_ROW):
        row_layout = []
        row_layout.append(sg.Text(row_no, key=('-TEXTNO-', r), size=2))
        row_no += 1
        for c in range(COLS):
            # Create a button for each cell
            row_layout.append(sg.Button(' ', size=(2, 1), key=(r, c), button_color=('white', 'dimgray'), pad=(1, 1)))
        layout.append(row_layout)
        row_layout.append(sg.Text('0xff', key=('-TEXT-', r)))

    layout.append([sg.StatusBar(key='-STATUS-', pad=((1, 1),(5, 2)), expand_x=True, size=(34, 1), text=EMPTY_FILE_STR if file_path is None else file_path)])
    window = sg.Window('Font Editor', layout, finalize=True)
    window.bind("<Control-s>", "SAVE_SHORTCUT")
    window.bind("<Control-o>", "OPEN_SHORTCUT")
    window.bind("<Control-c>", "COPY_SHORTCUT")
    window.bind("<Control-v>", "PASTE_SHORTCUT")
    # Bind key presses to the spin element
    window['-SPIN-'].bind('<KeyRelease>', ' Key') # ' Key' is added to the key name

    # Event Loop
    while True:
        event, values = window.read()
        if event in (sg.WIN_CLOSED, 'Exit'):
            break

        if isinstance(event, tuple): # Check if a button in the grid was clicked
            # Toggle color
            current_color = window[event].ButtonColor
            new_color = ('white', 'white') if current_color[1] == 'dimgray' else ('white', 'dimgray')
            window[event].update(button_color=new_color)

            row, _ = event
            file_data = update_file_data(file_data, values['-SPIN-'], row, update_gui_row_text(window, row))
        elif event in ('-SPIN-', '-SPIN- Key'):
            current_char_id = get_spinner_value(values['-SPIN-'])

            if current_char_id and MIN_CHAR_CODE <= int(current_char_id) <= MAX_CHAR_CODE:
                update_gui(window, file_data, current_char_id)
                window['-HEX-'].update('hex: ' + hex(current_char_id))
            else:
                window['-HEX-'].update('hex: -')
        elif event in ('Open...   Ctrl+O', "OPEN_SHORTCUT"):
            file_path = sg.popup_get_file('Please select a file', default_extension=".rom", no_window=True,
                                          file_types=(("ROM Files", "*.rom"), ("Binary Files", "*.bin"), ("Any file", "*.*")))

            if file_path:
                set_statusbar_msg(window['-STATUS-'], file_path)
                file_data = file_open(file_path)
                update_gui(window, file_data, values['-SPIN-'])
        elif event in ('Save       Ctrl+S', "SAVE_SHORTCUT"):
            if file_path is None:
                file_path = get_save_path(sg)

            if file_path and file_save(file_path, file_data):
                sg.popup_quick_message('File successfully saved!', background_color='green')
        elif event == 'Save as...':
            file_path = get_save_path(sg)

            if file_path:
                set_statusbar_msg(window['-STATUS-'], file_path)
                file_save(file_path, file_data)
        elif event == 'Clear':
            current_char_id = get_spinner_value(values['-SPIN-'])
            if current_char_id:
                for row in range(MIN_ROW, MAX_ROW):
                    file_data = update_file_data(file_data, current_char_id, row, 0xFF)
                update_gui(window, file_data, current_char_id)
        elif event in ('Copy     Ctrl+C', "COPY_SHORTCUT"):
            text = ''
            for r in range(MIN_ROW, MAX_ROW):
                text += hex(get_row_value(window, r)) + ', '
            sg.clipboard_set(text[:-2])
            #sg.popup_quick_message('Copied to clipboard!', background_color='green')
        elif event in ('Paste    Ctrl+V', "PASTE_SHORTCUT"):
            text = sg.clipboard_get()

            if isinstance(text, str):
                row_values = text.replace(' ', '').split(',')

                if len(row_values) == (MAX_ROW - MIN_ROW):
                    char_id = get_spinner_value(values['-SPIN-'])
                    if char_id:
                        for r in range(MIN_ROW, MAX_ROW):
                            file_data = update_file_data(file_data, char_id, r, int(row_values[r - MIN_ROW], 16))
                        update_gui(window, file_data, char_id)

        elif event == 'New':
            choice = sg.popup_yes_no("All changes will be lost!\nDo you really want to start new character set design?", title='Warning')

            if choice == 'Yes':
                file_data = b'\xFF' * 4096
                window['-SPIN-'].update(INIT_CHAR_CODE)
                set_statusbar_msg(window['-STATUS-'], EMPTY_FILE_STR)
                update_gui(window, file_data, INIT_CHAR_CODE)
        elif event == 'View font...':
            font_view_window(file_data)
        elif event == 'About...':
            sg.popup('Galaksija 2024 Font Editor', 'Copyright 2026 Vitomir Spasojević', 'Version 1.2', button_justification='c')

    window.close()


def file_open(file_path):
    try:
        with open(file_path, 'rb') as file:
            return file.read()
    except FileNotFoundError:
        print(f"Error: The file '{file_path}' was not found.")
    except (IOError, UnicodeDecodeError):
        print(f"Error reading the file '{file_path}'.")
    except PermissionError:
        print("Error: Permission denied. Cannot write to the file.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
    return None


def file_save(file_path, file_data):
    try:
        with open(file_path, 'wb') as file:
            return file.write(file_data) == len(file_data)
    except FileNotFoundError:
        print("Error: The file was not found.")
    except PermissionError:
        print("Error: Permission denied. Cannot write to the file.")
    except OSError as e:
        print(f"An unexpected OS error occurred: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
    return False

def get_save_path(sg):
    file_path = sg.popup_get_file(
        "Choose where to save",
        save_as=True,
        no_window=True,
        default_extension=".rom",
        file_types=(("ROM Files", "*.rom"), ("Binary Files", "*.bin"), ("Any file", "*.*"))
    )

    return file_path


def update_file_data(file_data, char_id, row, row_value):
    char_addr = get_char_address(char_id, row)
    return file_data[:char_addr] + reverse_byte(row_value).to_bytes(1, 'little') + file_data[char_addr + 1:]


def update_gui(window, file_data, char_id):
    for row in range(MIN_ROW, MAX_ROW):
        char_addr = get_char_address(char_id, row)
        char_row_byte = file_data[char_addr]

        # Update color for a row
        for col in range(COLS):
            col_bit = (char_row_byte >> col) & 1
            new_color = ('white', 'dimgray') if col_bit else ('white', 'white')
            window[(row, col)].update(button_color=new_color)

        update_gui_row_text(window, row)


def update_gui_row_text(window, row):
    row_value = get_row_value(window, row)
    window[('-TEXT-', row)].update(hex(row_value))
    return row_value


def get_row_value(window, row):
    row_value = 0
    col_value = 128

    # Read all buttons in the clicked row and calculate row value
    for c in range(COLS):
        button_key = (row, c)
        btn_value = 0 if window[button_key].ButtonColor[1] == 'white' else 1
        row_value += int(col_value) * btn_value
        col_value /= 2

    return row_value

# Character address in a CharGen file:
# A0 - D0 ASCII code
# A1 - D1 ASCII code
# A2 - D2 ASCII code
# A3 - D3 ASCII code
# A4 - D4 ASCII code
# A5 - D5 ASCII code
# A6 - D7 (0 - ASCII code, 1 - TextGraph)
# A7 - 0 latch bit 1 (four latch bits select character row)
# A8 - 0 latch bit 2
# A9 - 0 latch bit 3
# A10 - 0 latch bit 4
# A11 - 0 D6 (CharSet?)
# First 12 bits are used in standard Galaksija 2024 mode
# A12 - HiRes flip-flop (0 - text mode, 1 - graphic mode)
# A13 - 0
# A14 - 0 latch bit 6

def get_char_address(char_id, row):
    return char_id & 0x3F | (char_id & 0x80) >> 1 | (row & 0x0F) << 7 | (char_id & 0x40) << 5


def reverse_byte(b):
    # Reverses the bits of a single byte (integer 0-255) using bit manipulation.
    reversed_byte = 0
    for i in range(8):
        reversed_byte <<= 1 # Shift the result left by 1 to make space for the new bit
        reversed_byte |= (b & 1) # Extract the least significant bit of 'b' and add it to the result
        b >>= 1 # Shift 'b' right by 1 to process the next bit
    return reversed_byte

def set_statusbar_msg(statusbar, msg):
    statusbar.SetTooltip(None if msg == EMPTY_FILE_STR else msg)
    statusbar.update(msg)

def get_spinner_value(value):
    try:
        return None if value == '' else int(value)
    except Exception as e:
        sg.popup_error(f'An error occurred: {e}')
    return None

def font_view_window(file_data):
    # Dimensions of the bitmap (width x height)
    WIDTH, HEIGHT = 412, 140
    PIXEL_SIZE = 1  # Size of each pixel in graph units

    # Layout
    layout = [
        [sg.Graph(
            canvas_size=(WIDTH * PIXEL_SIZE, HEIGHT * PIXEL_SIZE),
            graph_bottom_left=(0, 0),
            graph_top_right=(WIDTH, HEIGHT),
            key='-GRAPH-')],
            #background_color='white')],
        [sg.Button('Close')]
    ]

    window = sg.Window('Font Viewer', layout, element_justification='center', modal=True, finalize=True)
    graph = window['-GRAPH-']
    spacing = 0

    for char_id in range(MIN_CHAR_CODE, MAX_CHAR_CODE):
        quotient, remainder = divmod(char_id - MIN_CHAR_CODE, 32)
        spacing = 0 if remainder == 0 else spacing + 5

        for row in range(MIN_ROW, MAX_ROW):
            char_addr = get_char_address(char_id, row)
            char_row_byte = file_data[char_addr]

            for col in range(COLS):
                col_bit = (char_row_byte >> col) & 1
                color = 'black' if col_bit == 1 else 'white'
                graph.draw_point((remainder * COLS + col + spacing, HEIGHT - (MAX_ROW + row + quotient * 16)), size=PIXEL_SIZE, color=color)

    # Event Loop
    while True:
        event, _ = window.read()
        if event in (sg.WIN_CLOSED, 'Close'):
            break

    window.close()

if __name__ == "__main__":
    main()