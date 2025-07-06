import React from 'react';
import { Typography } from '@mui/material';

const DeliveryAssignments: React.FC = () => {
  return (
    <div>
      <Typography variant="h4" gutterBottom>
        Delivery Assignments
      </Typography>
      <Typography variant="body1">
        Manage delivery assignments here.
      </Typography>
    </div>
  );
};

export default DeliveryAssignments;