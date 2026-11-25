using System;

namespace gestordj
{
    internal class clGlobales
    {
        static public string dbn = "Gestor_DJ"; 
        static public string server = @"danna\SQLEXPRESS";
        static public string password = "danna_paola";
        static public string security = "Persist Security Info=True";
        static public string UserID = "sa";
        static public string miconexion = "Data Source=" + server +
            ";Initial Catalog=" + dbn + ";User ID=" + UserID +
            ";Password=" + password + ";Persist Security Info=True";

        static public int idEmpleadoActual = 0;
        static public string nombreEmpleadoActual = "";
        static public string rolActual = "";
    }
}