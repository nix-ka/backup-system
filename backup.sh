#!/bin/bash
# Backup-Skript mit sudo-Unterstützung

# --- Funktionen für Benutzer- und Pfadmanagement ---
get_user_home() {
  # Ermittelt das HOME des ursprünglichen Benutzers (auch bei sudo)
  if [ -n "$SUDO_USER" ]; then
    echo "$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  else
    echo "$HOME"
  fi
}

user_home=$(get_user_home)
backup="backup"

# --- Initiale Einrichtung ---
if ! grep -q "alias $backup=" "$user_home/.bashrc"; then
  mkdir -p "$user_home/.backup-files/systems"
  echo "alias $backup='sudo bash $user_home/.backup-files/backup.sh'" >> "$user_home/.bashrc"
  rsync -ah --info=progress2 "$0" "$user_home/.backup-files"
  echo "Setup abgeschlossen. Nutzen Sie 'backup' mit sudo."
  echo -e "\033[31mFalls der Befehl nicht funktioniert: 'source ~/.bashrc' oder neues Terminal.\033[0m"
  exit 0
fi

# --- Variablen und Optionen ---
delete_files=false
create_files=false
restore_files=false
update_files=false
backup_name=""

while getopts "d:cr:u:" opt; do
  case ${opt} in
    d) delete_files=true; backup_name="${OPTARG}" ;;
    c) create_files=true ;;
    r) restore_files=true; backup_name="${OPTARG}" ;;
    u) update_files=true; backup_name="${OPTARG}" ;;
    *) echo -e "\033[31mUngültige Option\033[0m"; exit 1 ;;
  esac
done

# --- Löschen eines Backups (mit sudo) ---
if [ "$delete_files" = true ]; then
  if [ -f "$user_home/.backup-files/systems/$backup_name.sh" ]; then
    sudo rm -f "$user_home/.backup-files/systems/$backup_name.sh"
    sudo rm -f "$user_home/.backup-files/systems/${backup_name}-r.sh"
  fi

  if grep -q "alias $backup_name=" "$user_home/.bashrc"; then
    sudo sed -i "/alias $backup_name=/d" "$user_home/.bashrc"
    echo -e "\033[32mAlias '$backup_name' entfernt.\033[0m"
  else
    echo -e "\033[31mAlias '$backup_name' existiert nicht.\033[0m"
  fi
  exit 0
fi

# --- Backup-System erstellen/updaten ---
if [ "$create_files" = true ] || [ "$update_files" = true ]; then
  if [ "$update_files" = true ]; then
    script_name="$backup_name"
    backup_script="$user_home/.backup-files/systems/$script_name.sh"
    first_path=$(sed -n '3p' "$backup_script" | cut -c17-)
    second_path=$(sed -n '4p' "$backup_script" | cut -c17-)
  else
    echo "Name des Backup-Systems:"
    read script_name
    echo "Originalpfad (absolut, z. B. /var/www):"
    read first_path
    echo "Backup-Pfad (absolut, z. B. /backups):"
    read second_path
  fi

  # Erstelle Verzeichnisse mit sudo, falls nötig
  sudo mkdir -p "$first_path"
  sudo mkdir -p "$second_path"
  sudo chown -R "$(whoami)" "$first_path" "$second_path"  # Anpassen nach Bedarf

  # Backup-Skript generieren
  backup_script_content="#!/bin/bash
# Backup: $script_name
sudo rsync -ah --delete --info=progress2 \"$first_path/\" \"$second_path/\"
echo -e '\033[32mBackup abgeschlossen!\033[0m'"

  echo "$backup_script_content" | sudo tee "$user_home/.backup-files/systems/$script_name.sh" > /dev/null
  sudo chmod +x "$user_home/.backup-files/systems/$script_name.sh"

  # Restore-Skript generieren
  restore_script_content="#!/bin/bash
# Restore: $script_name
sudo rsync -ah --delete --info=progress2 \"$second_path/\" \"$first_path/\"
echo -e '\033[32mRestore abgeschlossen!\033[0m'"

  echo "$restore_script_content" | sudo tee "$user_home/.backup-files/systems/${script_name}-r.sh" > /dev/null
  sudo chmod +x "$user_home/.backup-files/systems/${script_name}-r.sh"

  # Alias setzen
  ALIAS_CMD="alias $script_name='sudo bash $user_home/.backup-files/systems/$script_name.sh'"
  if grep -q "alias $script_name=" "$user_home/.bashrc"; then
    sudo sed -i "/alias $script_name=/d" "$user_home/.bashrc"
  fi
  echo "$ALIAS_CMD" | sudo tee -a "$user_home/.bashrc" > /dev/null

  echo -e "\033[32mBackup-System '$script_name' bereit.\033[0m"
  exit 0
fi

# --- Restore durchführen ---
if [ "$restore_files" = true ]; then
  if [ -f "$user_home/.backup-files/systems/${backup_name}-r.sh" ]; then
    sudo bash "$user_home/.backup-files/systems/${backup_name}-r.sh"
  else
    echo -e "\033[31mBackup-System '$backup_name' existiert nicht.\033[0m"
  fi
  exit 0
fi

# --- Hilfe anzeigen ---
echo "Verwendung:"
echo "  sudo backup -c          # Neues Backup-System erstellen"
echo "  sudo backup -d [NAME]   # Backup löschen"
echo "  sudo backup -r [NAME]   # Restore durchführen"
echo "  sudo backup -u [NAME]   # Backup-System updaten"