NTPasswd: F3 | 0fF407 | F5                          Выход: 0f<ESC>07
0f
  ======== chntpw Main Interactive Menu ========
  <...>
   1 - Edit user data and passwords
07
Нажимаем 1.
Видим таблицу с именами, номерами и статусами пользователей:
0f
  ===== chntpw Edit User Info & Passwords ====

  | RID -|---------- Username ------------| Admin? |- Lock? --|
  | 03e8 | admin                          | ADMIN  |          |
07
Первое поле - номер пользователя. Для выбора по нему нужно ввести: 0f0xномер07. Второе - имя пользователя (кириллица не поддерживается). Третье - статус (снимать пароль нужно обычно у администратора). Четвёртое - заблокирован ли пользователь, пуст ли его пароль.
0f
  Select: ! - quit, . - list users, 0x - User with RID (hex)
  or simply enter the username to change:
07
Делаем осознанный выбор.

