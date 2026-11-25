using System;
using System.Data;
using System.Data.SqlClient;

namespace gestordj
{
    internal class clConexion
    {
        private string sentencial;

        public clConexion() { }

        public clConexion(string sentencia)
        {
            sentencial = sentencia;
        }

        public string ejecutar()
        {
            if (string.IsNullOrWhiteSpace(clGlobales.miconexion))
                throw new InvalidOperationException("La cadena de conexión está vacía.");

            using (SqlConnection conn = new SqlConnection(clGlobales.miconexion))
            {
                conn.Open();
                using (SqlCommand cmd = new SqlCommand(sentencial, conn))
                {
                    cmd.ExecuteNonQuery();
                }
            }
            return "Operacion exitosa";
        }

        public DataSet consultar()
        {
            var datos = new DataSet();
            if (string.IsNullOrWhiteSpace(clGlobales.miconexion))
                throw new InvalidOperationException("La cadena de conexión está vacía.");

            using (var conn = new SqlConnection(clGlobales.miconexion))
            using (var resp = new SqlDataAdapter(sentencial, conn))
            {
                conn.Open();
                resp.Fill(datos, "Tabla");
            }
            return datos;
        }
    }
}