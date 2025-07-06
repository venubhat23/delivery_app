import React from 'react';
import { Typography } from '@mui/material';

const Customers: React.FC = () => {
  return (
    <div>
      <Typography variant="h4" gutterBottom>
        Customers
      </Typography>
      <Typography variant="body1">
        Manage your customers here.
      </Typography>
    </div>
  );
};

export default Customers;