using System;
using System.Windows.Forms;

namespace gestordj
{
    public partial class frmLogin : Form
    {
        public frmLogin()
        {
            InitializeComponent();
            lblError.Visible = false;

            txtUsuario.MaxLength = 30;
            txtPassword.MaxLength = 15;
        }

        private void btnIniciar_Click(object sender, EventArgs e)
        {
            lblError.Visible = false;

            if (string.IsNullOrWhiteSpace(txtUsuario.Text) || string.IsNullOrWhiteSpace(txtPassword.Text))
            {
                lblError.Text = "Por favor, ingresa usuario y contraseña.";
                lblError.Visible = true;
                return;
            }

            try
            {
                clLogin login = new clLogin(txtUsuario.Text.Trim(), txtPassword.Text.Trim());

                if (login.ValidarAcceso())
                {
               
                    this.Hide();
                }
                else
                {
                    lblError.Text = "Acceso denegado: datos incorrectos o empleado inactivo.";
                    lblError.Visible = true;
                    txtPassword.Clear();
                    txtPassword.Focus();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("Error de conexión: " + ex.Message, "GESTOR-DJ", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void btnSalir_Click(object sender, EventArgs e)
        {
            Application.Exit();
        }
    }
}