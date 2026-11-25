using System;
using System.Data;

namespace gestordj
{
    internal class clLogin
    {
        private string usuario;
        private string contrasena;

        public clLogin() { }

        public clLogin(string usuario, string contrasena)
        {
          
            this.usuario = usuario.Replace("'", "''");
            this.contrasena = contrasena.Replace("'", "''");
        }

        public bool ValidarAcceso()
        {
            string querySelect = $@"
                SELECT 
                    U.id_usuario,
                    E.id_empleado,
                    (E.nombre + ' ' + E.apellido) AS nombre_completo,
                    R.nombre_rol
                FROM USUARIOS U
                INNER JOIN EMPLEADOS E ON U.id_empleado = E.id_empleado
                INNER JOIN ROLES R ON E.id_rol = R.id_rol
                WHERE U.usuario = '{usuario}' 
                  AND U.contrasena = '{contrasena}' 
                  AND E.estado = 1";

            clConexion con = new clConexion(querySelect);
            DataSet ds = con.consultar();

            if (ds.Tables["Tabla"].Rows.Count > 0)
            {
                DataRow fila = ds.Tables["Tabla"].Rows[0];
                int idUsuario = Convert.ToInt32(fila["id_usuario"]);

                
                clGlobales.idEmpleadoActual = Convert.ToInt32(fila["id_empleado"]);
                clGlobales.nombreEmpleadoActual = fila["nombre_completo"].ToString();
                clGlobales.rolActual = fila["nombre_rol"].ToString();

               
                string queryUpdate = $"UPDATE USUARIOS SET ultimo_acceso = GETDATE() WHERE id_usuario = {idUsuario}";
                clConexion conUpdate = new clConexion(queryUpdate);
                conUpdate.ejecutar();

                return true;
            }

            return false;
        }
    }
}