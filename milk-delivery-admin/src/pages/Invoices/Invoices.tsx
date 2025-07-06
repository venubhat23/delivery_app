import React from 'react';
import { Typography } from '@mui/material';

const Invoices: React.FC = () => {
  return (
    <div>
      <Typography variant="h4" gutterBottom>
        Invoices
      </Typography>
      <Typography variant="body1">
        Manage invoices here.
      </Typography>
    </div>
  );
};

export default Invoices;