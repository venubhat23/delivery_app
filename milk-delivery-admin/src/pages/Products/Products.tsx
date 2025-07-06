import React from 'react';
import { Typography } from '@mui/material';

const Products: React.FC = () => {
  return (
    <div>
      <Typography variant="h4" gutterBottom>
        Products
      </Typography>
      <Typography variant="body1">
        Manage your products here.
      </Typography>
    </div>
  );
};

export default Products;