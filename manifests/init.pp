class standalone (
  $base_path,
){

  # Useful script to force a puppet run at any time
  file { '/usr/local/sbin/repuppet':
    mode    => '0750',
    content => template("${module_name}/repuppet.erb"),
  }


}
