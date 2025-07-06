import React from 'react';
import { Typography } from '@mui/material';

const Users: React.FC = () => {
  return (
    <div>
      <Typography variant="h4" gutterBottom>
        Users
      </Typography>
      <Typography variant="body1">
        Manage users and delivery people here.
      </Typography>
    </div>
  );
};

export default Users;