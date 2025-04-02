#!/bin/bash
backup="backup" 

if ! grep -q "alias $backup=" "$HOME/.bashrc"; then
    mkdir -p "$HOME/.backup-files/systems"
    echo "alias $backup='bash $HOME/.backup-files/backup.sh'" >> "$HOME/.bashrc"
    rsync -ah --info=progress2 "$0" "$HOME/.backup-files"
    echo 'Es wurde alles automatisch eingerichtet. Sie können nun den Befehl "backup" nutzen.'
    echo -e "\033[31mWenn der Befehl nicht funktioniert, geben Sie 'source ~/.bashrc' ein oder öffnen Sie ein neues Terminal.\033[0m"
    exit 0
fi

delete_files=false
create_files=false
restore_files=false
update_files=false
backup_name=""
restore_script_content=""
backup_script_content=""

while getopts "d:cr:u:" opt; do
  case ${opt} in
    d)
      delete_files=true
      backup_name="${OPTARG:-}"
      ;;
    c)
      create_files=true
      ;;
    r)
      restore_files=true
      backup_name="${OPTARG:-}"
      ;; 
    u)
      create_files=true
      update_files=true
      backup_name="${OPTARG:-}"
      ;; 
    *)
      echo -e "\033[31mUngültige Option\033[0m"
      exit 1
      ;;
  esac
done

if [ "$delete_files" = true ]; then
    if [ -f "$HOME/.backup-files/systems/$backup_name.sh" ]; then
      rm "$HOME/.backup-files/systems/$backup_name.sh"
      rm "$HOME/.backup-files/systems/${backup_name}-r.sh"
    fi

    if grep -q "alias $backup_name=" "$HOME/.bashrc"; then
      sed -i "/alias $backup_name=/d" "$HOME/.bashrc"
      echo -e "\033[32mDer Befehl '$backup_name' wurde gelöscht.\033[0m"
    else
      echo -e "\033[31mDer Befehl '$backup_name' existiert nicht\033[0m"
    fi

    exit 0
fi

if [ "$create_files" = true ]; then
  if [ "$update_files" = true ]; then
  script_name="$backup_name"
  backup_script="$HOME/.backup-files/systems/$backup_name.sh"
  first_path=$(sed -n '3p' "$backup_script" | cut -c17-)
  second_path=$(sed -n '4p' "$backup_script" | cut -c17-)
  echo "$first_path  $second_path"
  else
  echo "Gib einen Namen für das Backup System ein:"
  read script_name

  echo "Gib den Pfad vom Original Verzeichnis ein:"
  read first
  first_path="$HOME/$first"

  echo "Gib den Pfad für das Backup ein:"
  read second
  second_path="$HOME/$second"
  fi

  mkdir -p "$first_path"
  mkdir -p "$second_path"

 backup_script_content="#!/bin/bash
# Backup-Skript $script_name
# Backup-Skript $first_path
# Backup-Skript $second_path

rm -rf "$second_path"/*
rm -rf "$second_path"/.*
rsync -ah --info=progress2 "$first_path/" "$second_path/"
echo -e '\033[32mBackup abgeschlossen!\033[0m'
"

echo "$backup_script_content" > "$HOME/.backup-files/systems/$script_name.sh"
chmod +x "$HOME/.backup-files/systems/$script_name.sh"


  restore_script_content="#!/bin/bash
  # Backup-Skript $script_name

  rm -rf "$HOME/$first_path"/*
  rm -rf "$HOME/$first_path"/.*
  rsync -ah --info=progress2 \"\$HOME/$second_path/\" \"\$HOME/$first_path/\"
  echo -e '\033[32mRestore abgeschlossen!\033[0m'
  "
  echo "$restore_script_content" > "$HOME/.backup-files/systems/${script_name}-r.sh"
  chmod +x "$HOME/.backup-files/systems/${script_name}-r.sh"

  ALIAS_COMMAND="alias $script_name='bash $HOME/.backup-files/systems/$script_name.sh'"

  if grep -q "$script_name" "$HOME/.bashrc"; then
    sed -i "/$script_name/d" "$HOME/.bashrc"
  fi

  echo "$ALIAS_COMMAND" >> "$HOME/.bashrc"

  echo -e "\033[32mDu kannst das Backup nun mit '$script_name' im Terminal ausführen.\033[0m"
  echo -e "\033[31mWenn der Befehl nicht funktioniert, geben Sie 'source ~/.bashrc' ein oder öffnen Sie ein neues Terminal.\033[0m"
  exit 0
fi

if [ "$restore_files" = true ]; then
  if [ -f "$HOME/.backup-files/systems/${backup_name}-r.sh" ]; then
    bash "$HOME/.backup-files/systems/${backup_name}-r.sh"
    exit 0
  else
    echo -e "\033[31mDer Befehl '$backup_name' existiert nicht\033[0m"
    exit 0
  fi
fi

echo "- Mit der Option -c erstellen Sie ein neues Backup System."
echo "- Mit der Option -d (Backup Namen) löschen Sie ein vorhandenes Backup System."
echo "- Mit der Option -r (Backup Namen) restoren Sie ein vorhandenes Backup."
echo "- Mit der Option -u (Backup Namen) updaten Sie ein vorhandenes Backup damit es mit den neusten änderungen funktioniert."
